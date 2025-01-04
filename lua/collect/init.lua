local Item = require("collect.item")
local M = {}
M.namespace = vim.api.nvim_create_namespace("collect.nvim")

---@class Collect.Options
---@field match Collect.MatchConfig[]

---Sets up the plugin.
---@param opts Collect.Options|nil The configuration options.
function M.setup(opts)
	if opts then
		---@type Collect.MatchConfig[]
		M.match = opts.match
	else
		M.match = {}
	end

	---@type Collect.Item[] The set of items found.
	M.items = {}
	---@type boolean[] The set of known item keys.
	M.known = {}
	---@type integer The current navigation index.
	M.index = 0
	---@type integer The buffer ID.
	M.bufnr = -1
	---@type integer The window ID.
	M.winnr = -1
	M.cur_mark = nil
end

function M.clear()
	M.items = {}
	M.known = {}
	M.index = 0
	vim.api.nvim_buf_clear_namespace(M.bufnr, M.namespace, 0, -1)
end

function M.next()
	M.reset_mark()
	M.index = M.index + 1

	if M.index > #M.items then
		M.index = #M.items
		vim.notify("No item found", vim.log.levels.WARN)
	else
		M.goto()
	end
end

function M.prev()
	M.reset_mark()
	M.index = M.index - 1

	if M.index <= 0 then
		M.index = math.min(1, #M.items)
		vim.notify("No item found", vim.log.levels.WARN)
	else
		M.goto()
	end
end

local function with_window(fun)
	local win = vim.api.nvim_get_current_win()
	M.show(true)
	fun()
	vim.api.nvim_set_current_win(win)
end

function M.reset_mark()
	if M.cur_mark then
		vim.api.nvim_buf_del_extmark(M.bufnr, M.namespace, M.cur_mark)
		M.cur_mark = nil
	end
end

function M.goto()
	local item = M.items[M.index]

	if item then
		vim.notify("[" .. M.index .. "/" .. #M.items .. "] " .. item.message)

		with_window(function()
			vim.api.nvim_set_current_win(M.winnr)
			vim.api.nvim_win_set_cursor(0, { item.msg_lnum, 0 })

			local opts = {
				end_row = item.msg_lnum + #item.regex - 2,
				hl_eol = true,
				line_hl_group = "Visual",
				hl_mode = "combine",
				--ephemeral = true,
				--priority = 200,
			}

			M.cur_mark = vim.api.nvim_buf_set_extmark(
				item.msg_bufnr,
				M.namespace,
				item.msg_lnum - 1,
				0,
				opts)
		end)

		if vim.fn.filereadable(item.path) == 1 then
			local lnum = tonumber(item.lnum)
			vim.cmd("silent edit " .. item.path)

			if lnum then
				vim.api.nvim_win_set_cursor(0, { lnum, 0 })
			end
		else
			vim.notify("File not found in current working directory.", vim.log.levels.ERROR)
		end
	else
		vim.notify("No item found", vim.log.levels.WARN)
	end
end

function M.toggle(focus)
	if not vim.api.nvim_win_is_valid(M.winnr) then
		M.show(focus)
	else
		M.hide()
	end
end

function M.show(focus)
	if not vim.api.nvim_buf_is_valid(M.bufnr) then
		M.bufnr = vim.api.nvim_create_buf(false, true)
	end

	if not vim.api.nvim_win_is_valid(M.winnr) then
		local height = math.floor(vim.o.lines / 4)
		local win = vim.api.nvim_get_current_win()

		M.winnr = vim.api.nvim_open_win(M.bufnr, true, {
			split  = "below",
			win    = -1,
			height = height,
		})

		if vim.bo[M.bufnr].buftype ~= "terminal" then
			vim.cmd.terminal("nu")

			vim.api.nvim_buf_attach(M.bufnr, false, {
				on_lines = function(_, _, _, first, last)
					local items = Item.match(M.bufnr, first, last, M.match)

					for _, item in ipairs(items) do
						if not M.known[item.key] then
							table.insert(M.items, item)
							M.known[item.key] = true

							local opts = {
								end_row = item.msg_lnum + #item.regex - 2,
								hl_eol = true,
								sign_text = "H",
								line_hl_group = "DiagnosticSignHint",
								sign_hl_group = "DiagnosticSignHint",
								hl_mode = "combine",
							}

							if item.type == "error" then
								opts.sign_text = "E"
								opts.sign_hl_group = "DiagnosticSignError"
								opts.line_hl_group = "DiagnosticSignError"
							elseif item.type == "warn" then
								opts.sign_text = "W"
								opts.sign_hl_group = "DiagnosticSignWarn"
								opts.line_hl_group = "DiagnosticSignWarn"
							elseif item.type == "info" then
								opts.sign_text = "I"
								opts.sign_hl_group = "DiagnosticSignInfo"
								opts.line_hl_group = "DiagnosticSignInfo"
							end

							vim.api.nvim_buf_set_extmark(
								item.msg_bufnr,
								M.namespace,
								item.msg_lnum - 1,
								0,
								opts)
						end
					end
				end
			})
		end

		if focus then
			vim.cmd.startinsert()
		else
			vim.api.nvim_set_current_win(win)
		end
	elseif focus then
		vim.api.nvim_set_current_win(M.winnr)
	end
end

function M.hide()
	if vim.api.nvim_win_is_valid(M.winnr) then
		vim.api.nvim_win_hide(M.winnr)
	end
end

function M.send(cmd)
	if M.bufnr >= 0 then
		vim.fn.chansend(vim.bo[M.bufnr].channel, cmd .. "\r\n")

		with_window(function()
			vim.cmd("norm G")
		end)
	end
end

function M.build()
	M.show()
	M.clear()
	M.send("clear")
	M.send("cargo build")
end

return M
