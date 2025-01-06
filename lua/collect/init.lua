local Item = require("collect.item")

-- # Terminology:
-- 
-- The plugin provides a *terminal* window that can be toggled on and off. The output of
-- commands that run inside that window will automatically be scanned against the regular
-- expressions configured, producing a list of *matches*.
--
-- Every match has a *source*, which is the location of the terminal output that produced
-- the match (ie. the position of the error/warning message itself) and a *target*, which
-- is the location returned by the match (ie. the position of the error/warning in code).
--
-- There is a *current match*, which can be navigated by calling `prev()` and `next()`.
-- This may also (depending on the options set) change the cursor position in different
-- windows:
--
-- When triggering a navigation action, the *source* position is shown in the *terminal*
-- window, while the *target* position is shown in the *view* window. The *view* is set
-- to the current window, when a navigation action is triggered from a non-*terminal*
-- window.

---@class Collect.Options
---@field match Collect.MatchConfig[]

---@class Collect.Module
---@field _namespace integer The extmark namespace.
---@field _opts Collect.Options The options used.
---@field _matches Collect.Item[]
---@field _known { string: boolean }
---
---@field _buffer integer The ID of the terminal buffer. -1 when not initialized.
---@field _window integer The ID of the toggle window. -1 when closed.
---@field _mark   integer The ID of the current item mark. -1 when not set.
---@field _index  integer The index of the currently selected item. 0 when not selected.
---@field _view   integer The ID of the window used for viewing files. -1 when not set.
---
---@field cur_mark integer?
---@field setup function
---@field clear function
---@field next function
---@field prev function
---@field clear_mark function
---@field mark function
---@field goto function
---@field goto_source function
---@field mark_source function
---@field goto_target function
---@field toggle function
---@field show function
---@field hide function
---@field send function
---@field build function

---@type Collect.Module
---@diagnostic disable-next-line: missing-fields
local M = {
	_matches = {},
	_known = {},
	_namespace = vim.api.nvim_create_namespace("collect.nvim"),
	_buffer = -1,
	_window = -1,
	_mark = -1,
	_view = -1,
	_index = 0,
}

---Sets up the plugin.
---@param opts Collect.Options|nil The configuration options.
function M.setup(opts)
	local def_opts = {
		match = {}
	}

	M._opts = vim.tbl_deep_extend("force", def_opts, opts or {})
end

---Clears the list of captured items.
function M.clear()
	M._index = 0
	M._mark = -1
	M._matches = {}
	M._known = {}
	vim.api.nvim_buf_clear_namespace(M._buffer, M._namespace, 0, -1)
end

---Clears the extmark for the current item.
function M.clear_mark()
	if M._mark then
		vim.api.nvim_buf_del_extmark(M._buffer, M._namespace, M._mark)
		M._mark = nil
	end
end

---Scans through items in the given direction, until `filter` returns a truthy value.
---Then sets `M._index` accordingly.
---@return `true` on success; `false` if no item was found.
local function scan(opts, dir)
	local def_opts = {
		filter = function(_)
			return true
		end,
		notify = function(index, total, item)
			if index then
				vim.notify("[" .. index .. "/" .. total .. "] " .. item.message)
			else
				vim.notify("No item found", vim.log.levels.WARN)
			end
		end
	}

	opts = vim.tbl_extend("force", def_opts, opts or {})

	M.clear_mark()
	local index = M._index

	while true do
		index = index + dir

		if index <= 0 or index > #M._matches then
			opts.notify()
			return false
		end

		if opts.filter(M._matches[index]) then
			M._index = index
			opts.notify(M._index, #M._matches, M._matches[M._index])
			return true
		end
	end
end

local function with_window(fun)
	local win = vim.api.nvim_get_current_win()
	M.show(true)
	fun()
	vim.api.nvim_set_current_win(win)
end

---Navigates to the next item.
function M.next(opts)
	if scan(opts, 1) then
		M.goto()
	end
end

---Navigates to the previous item.
function M.prev(opts)
	if scan(opts, -1) then
		M.goto()
	end
end

---Sets the cursor in the terminal buffer to the source of the current item.
function M.goto_source()
	local item = M._matches[M._index]

	if item then
		with_window(function()
			vim.api.nvim_set_current_win(M._window)
			vim.api.nvim_win_set_cursor(0, { item.msg_lnum, 0 })
		end)
	end
end

---Marks the currently selected item in the terminal buffer.
function M.mark_source()
	local item = M._matches[M._index]
	M.clear_mark()

	if item then
		local opts = {
			end_row = item.msg_lnum + #item.regex - 2,
			hl_eol = true,
			line_hl_group = "Visual",
			hl_mode = "combine",
		}

		M.cur_mark = vim.api.nvim_buf_set_extmark(
			item.msg_bufnr,
			M._namespace,
			item.msg_lnum - 1,
			0,
			opts)
	end
end

---Opens the path for the current match in the view window and sets the cursor position.
function M.goto_target()
	local item = M._matches[M._index]

	if item then
		local view = vim.api.nvim_get_current_win()

		if view ~= M._window then
			M._view = view
		else
			view = M._view
		end

		if not vim.api.nvim_win_is_valid(view) then
			vim.notify("No view window available.", vim.log.levels.WARN)
			return
		end

		vim.api.nvim_set_current_win(view)

		if vim.fn.filereadable(item.path) == 1 then
			local lnum = tonumber(item.lnum)
			local col = tonumber(item.col)
			vim.cmd("silent edit " .. item.path)

			if col then
				col = col - 1
			end

			if lnum then
				vim.api.nvim_win_set_cursor(0, { lnum, col or 0 })
			end
		else
			vim.notify("File not found in current working directory.", vim.log.levels.ERROR)
		end
	end
end

function M.goto()
	local item = M._matches[M._index]

	if item then
		M.mark_source()
		M.goto_source()
		M.goto_target()
	end
end

function M.toggle(focus)
	if not vim.api.nvim_win_is_valid(M._window) then
		M.show(focus)
	else
		M.hide()
	end
end

function M.show(focus)
	if not vim.api.nvim_buf_is_valid(M._buffer) then
		M._buffer = vim.api.nvim_create_buf(false, true)
	end

	if not vim.api.nvim_win_is_valid(M._window) then
		local height = math.floor(vim.o.lines / 4)
		local win = vim.api.nvim_get_current_win()

		M._window = vim.api.nvim_open_win(M._buffer, true, {
			split  = "below",
			win    = -1,
			height = height,
		})

		vim.opt_local.nu = false
		vim.opt_local.relativenumber = false

		if vim.bo[M._buffer].buftype ~= "terminal" then
			vim.cmd.terminal("nu")

			vim.api.nvim_buf_attach(M._buffer, false, {
				on_lines = function(_, _, _, first, last)
					local items = Item.match(M._buffer, first, last, M._opts.match)

					for _, item in ipairs(items) do
						if not M._known[item.key] then
							table.insert(M._matches, item)
							M._known[item.key] = true

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
								M._namespace,
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
		vim.api.nvim_set_current_win(M._window)
	end
end

function M.hide()
	if vim.api.nvim_win_is_valid(M._window) then
		vim.api.nvim_win_hide(M._window)
		M._window = -1
	end
end

function M.send(cmd)
	if M._buffer >= 0 then
		vim.fn.chansend(vim.bo[M._buffer].channel, cmd .. "\r\n")

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
