local Item = require("collect.item")

-- Matcher
-- GroupMatcher

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

local M = {
	namespace = vim.api.nvim_create_namespace("collect.nvim"),
	matches = {},
	known = {},
	buffer = -1,
	window = -1,
	view = -1,
	cur_mark = -1,
	cur_index = 0,
}

-------------------------------------------------------------------------------
-- Private functions
-------------------------------------------------------------------------------

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
	local index = M.cur_index

	while true do
		index = index + dir

		if index <= 0 or index > #M.matches then
			opts.notify()
			return false
		end

		if opts.filter(M.matches[index]) then
			M.cur_index = index
			opts.notify(M.cur_index, #M.matches, M.matches[M.cur_index])
			return true
		end
	end
end

---Runs the given function in the context of the terminal window.
---Then restores the previous window.
local function with_window(fun)
	local win = vim.api.nvim_get_current_win()
	M.show(true)
	fun()
	vim.api.nvim_set_current_win(win)
end

---Creates a matcher function from a matcher configuration.
local function new_matcher(config)
	if type(config) == "table" then
		return function(line)
			local groups = vim.fn.matchlist(line, config[1])
			local result = {}

			if groups[1] then
				for i = 2, #groups do
					result[groups[i]] = groups[i]
				end

				return result
			else
				return nil
			end
		end
	elseif type(config) == "function" then
		return config
	else
		vim.notify("Invalid matcher.", vim.log.levels.ERROR)
		return nil
	end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

---Sets up the plugin.
---@param opts Collect.Options|nil The configuration options.
function M.setup(opts)
	local def_opts = { match = {} }
	M.opts = vim.tbl_deep_extend("force", def_opts, opts or {})

	-- Configure components.
	require("collect.terminal").setup(M.opts.terminal)

	require("collect.group_matcher").setup(M.opts.match)
end

---Clears the list of matched items.
function M.clear()
	M.cur_index = 0
	M.cur_mark = -1
	M.matches = {}
	M.known = {}
	vim.api.nvim_buf_clear_namespace(M.buffer, M.namespace, 0, -1)
end

---Clears the current item mark.
function M.clear_mark()
	if M.cur_mark then
		vim.api.nvim_buf_del_extmark(M.buffer, M.namespace, M.cur_mark)
		M.cur_mark = nil
	end
end

---Clears / resets the terminal.
function M.reset()
	local show = vim.api.nvim_win_is_valid(M.window)
	local active = vim.api.nvim_get_current_win() == M.window

	M.hide()
	M.clear()

	if vim.api.nvim_buf_is_valid(M.buffer) then
		vim.api.nvim_buf_delete(M.buffer, { force = true })
		M.buffer = -1
	end

	if show then
		M.show(active)
	end
end

---Navigates to the next item.
---See `goto_current` for available options.
function M.goto_next(opts)
	if scan(opts, 1) then
		M.goto_current(opts)
	end
end

---Navigates to the previous item.
---See `goto_current` for available options.
function M.goto_prev(opts)
	if scan(opts, -1) then
		M.goto_current(opts)
	end
end

---Navigates to the current item.
---
---# Options
---* mark_source: `true` to mark the source location in the terminal buffer.
---* goto_source: `true` to navigate to the source location in the terminal window.
---* goto_target: `true` to navigate to the target location in the view window.
function M.goto_current(opts)
	local item = M.matches[M.cur_index]

	if item then
		local def_opts = {
			mark_source = true,
			goto_source = true,
			goto_target = true,
		}

		opts = vim.tbl_extend("force", def_opts, opts or {})

		if opts.mark_source then
			M.mark_source()
		end

		if opts.goto_source then
			M.goto_source()
		end

		if opts.goto_target then
			M.goto_target()
		end
	end
end

---Sets the cursor in the terminal buffer to the source of the current item.
function M.goto_source()
	local item = M.matches[M.cur_index]

	if item then
		with_window(function()
			vim.api.nvim_set_current_win(M.window)
			vim.api.nvim_win_set_cursor(0, { item.msg_lnum, 0 })
		end)
	end
end

---Marks the currently selected item in the terminal buffer.
function M.mark_source()
	local item = M.matches[M.cur_index]
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
			M.namespace,
			item.msg_lnum - 1,
			0,
			opts)
	end
end

---Opens the path for the current match in the view window and sets the cursor position.
function M.goto_target()
	local item = M.matches[M.cur_index]

	if item then
		local view = vim.api.nvim_get_current_win()

		if view ~= M.window then
			M.view = view
		else
			view = M.view
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

---Toggles the visibility of the terminal window.
---See `show` for available options.
function M.toggle(opts)
	if not vim.api.nvim_win_is_valid(M.window) then
		M.show(opts)
	else
		M.hide()
	end
end

---Shows the terminal window.
---
---# Options
---* focus:  `true` to move the cursor into the terminal buffer.
---* insert: `true` to enter insert mode after focusing the terminal buffer.
function M.show(opts)
	local def_opts = {
		focus  = false,
		insert = true,
	}

	opts = vim.tbl_extend("force", def_opts, opts)

	if not vim.api.nvim_buf_is_valid(M.buffer) then
		M.buffer = vim.api.nvim_create_buf(false, true)
	end

	if not vim.api.nvim_win_is_valid(M.window) then
		local height = math.floor(vim.o.lines / 4)
		local win = vim.api.nvim_get_current_win()

		M.window = vim.api.nvim_open_win(M.buffer, true, {
			split  = "below",
			win    = -1,
			height = height,
		})

		vim.opt_local.nu = false
		vim.opt_local.relativenumber = false

		if vim.bo[M.buffer].buftype ~= "terminal" then
			vim.cmd.terminal("nu")

			vim.api.nvim_buf_attach(M.buffer, false, {
				on_lines = function(_, _, _, first, last)
					local items = Item.match(M.buffer, first, last, M.opts.match)

					for _, item in ipairs(items) do
						if not M.known[item.key] then
							table.insert(M.matches, item)
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

		if opts.focus then
			if opts.insert then
				vim.cmd.startinsert()
			end
		else
			vim.api.nvim_set_current_win(win)
		end
	elseif opts.focus then
		vim.api.nvim_set_current_win(M.window)
	end
end

---Hides the terminal window.
function M.hide()
	if vim.api.nvim_win_is_valid(M.window) then
		vim.api.nvim_win_hide(M.window)
		M.window = -1
	end
end

---Sends a command to the terminal.
---@param cmd string The command to run.
function M.send(cmd)
	if M.buffer >= 0 then
		vim.fn.chansend(vim.bo[M.buffer].channel, cmd .. "\r\n")

		-- Move to the end of the buffer (so that it auto-scrolls).
		with_window(function() vim.cmd("norm G") end)
	end
end

function M.build()
	M.show()
	M.clear()
	M.send("clear")
	M.send("cargo build")
end

return M
