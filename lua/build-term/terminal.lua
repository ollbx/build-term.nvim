--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@alias BuildTerm.Terminal.WindowConfig vim.api.keyset.win_config|(fun(): vim.api.keyset.win_config)|nil
---@alias BuildTerm.Terminal.NotifyFun fun(index: integer?, total: integer?, match: BuildTerm.Match?)
---@alias BuildTerm.Terminal.FilterFun fun(match: BuildTerm.Match): boolean?

---@class BuildTerm.Terminal.Config
---@field focus boolean? `true` to move the cursor into the terminal on open.
---@field shell string? Specifies the shell command to execute. `nil` for default.
---@field window BuildTerm.Terminal.WindowConfig The window configuration.
---@field on_init fun()? Terminal window initialization hook function.
---@field on_focus fun()? Terminal window focus hook function.

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local M = {}

---@class BuildTerm.Terminal
---@field buffer integer The terminal buffer (or -1 if uninitialized).
---@field window integer The terminal window (or -1 if hidden).
---@field matcher BuildTerm.GroupMatcher The group matcher to use.
---@field matches BuildTerm.Match[] The list of matches.
---@field index { integer: integer } Reverse lookup index.
---@field cur_index integer The currently selected match.
---@field cur_mark integer The mark for the currently selected match.
---@field namespace integer The extmark namespace used.
---@field config BuildTerm.Terminal.Config The terminal configuration.
---@field private __index any
local Terminal = {}
Terminal.__index = Terminal

---Creates a new terminal.
---@param matcher BuildTerm.GroupMatcher? The group matcher to use.
---@param config BuildTerm.Terminal.Config? The terminal config.
---@return BuildTerm.Terminal
function M.new(matcher, config)
	local def_config = {
		focus = false,
		shell = nil,
		-- Default window is 25% on the bottom.
		window = function()
			return {
				split = "below",
				height = math.floor(vim.o.lines / 4),
			}
		end,
		-- Default init function disables line numbers.
		on_init = function()
			vim.opt_local.nu = false
			vim.opt_local.relativenumber = false
		end,
		-- Default focus function enters insert mode.
		on_focus = function()
			vim.cmd.startinsert()
		end
	}

	if not matcher then
		local GroupMatcher = require("build-term.group_matcher")
		matcher = GroupMatcher.new()
	end

	local terminal = {
		buffer = -1,
		window = -1,
		matcher = matcher,
		matches = {},
		index = {},
		cur_index = 0,
		cur_mark = -1,
		namespace = vim.api.nvim_create_namespace(""),
		config = vim.tbl_extend("force", def_config, config or {}),
	}

	setmetatable(terminal, Terminal)
	return terminal
end

---Handles new output on the terminal buffer.
---@private
function Terminal:handle_output(first, last)
	-- Extend the area by the context required.
	local context = self.matcher:get_context()
	first = math.max(0, first - context)
	last = last + context

	-- Retrieve the changed lines and match on them.
	local lines = vim.api.nvim_buf_get_lines(self.buffer, first, last, false)
	local matches = self.matcher:scan(lines)

	for _, match in ipairs(matches) do
		-- 0-based index.
		local offset = first + match.offset - 1

		-- Search for existing extmarks that overlap our line.
		local found = vim.api.nvim_buf_get_extmarks(
			self.buffer,
			self.namespace,
			{ offset, 0 },
			{ offset, 0 },
			{ overlap = true })

		local old_mark = nil

		-- If there was a previous ID, update the existing entry.
		if #found > 0 then
			old_mark = found[1][1]
		end

		local config = {
			id = old_mark,
			end_row = offset + match.length - 1,
			hl_eol = true,
			sign_text = "H",
			sign_hl_group = "DiagnosticSignHint",
			hl_mode = "combine",
		}

		if match.matcher.type == "error" then
			config.sign_text = "E"
			config.sign_hl_group = "DiagnosticSignError"
		elseif match.matcher.type == "warn" then
			config.sign_text = "W"
			config.sign_hl_group = "DiagnosticSignWarn"
		elseif match.matcher.type == "info" then
			config.sign_text = "I"
			config.sign_hl_group = "DiagnosticSignInfo"
		end

		config.line_hl_group = config.sign_hl_group

		if match.matcher.mark_config then
			config = vim.tbl_extend("force", config, match.matcher.mark_config)
		end

		match.mark = vim.api.nvim_buf_set_extmark(
			self.buffer,
			self.namespace,
			offset,
			0,
			config)

		if old_mark then
			-- Replace the previous match.
			local index = self.index[old_mark]

			if index then
				self.matches[index] = match
			end
		else
			table.insert(self.matches, match)
			self.index[match.mark] = #self.matches
		end
	end
end

---Opens the terminal split.
---@param config BuildTerm.Terminal.Config? Configuration overrides.
function Terminal:open(config)
	config = vim.tbl_extend("force", self.config, config or {})

	-- Create a buffer if we have none.
	if not vim.api.nvim_buf_is_valid(self.buffer) then
		self:clear_matches()
		self.buffer = vim.api.nvim_create_buf(false, true)
	end

	-- Create the window if it is invalid.
	if not vim.api.nvim_win_is_valid(self.window) then
		local win_config = config.window

		if type(win_config) == "function" then
			win_config = win_config()
		end

		-- Create the window and switch to it.
		local prev_win = vim.api.nvim_get_current_win()
		win_config.win = -1
		self.window = vim.api.nvim_open_win(self.buffer, true, win_config)

		-- Initialize the window.
		config.on_init()

		-- If the buffer is not a terminal yet, enter terminal mode.
		if vim.bo[self.buffer].buftype ~= "terminal" then
			vim.cmd.terminal(config.shell)

			vim.api.nvim_buf_attach(self.buffer, false, {
				on_lines = function(_, _, _, first, last)
					self:handle_output(first, last)
				end
			})
		end

		if config.focus then
			config.on_focus()
		else
			vim.api.nvim_set_current_win(prev_win)
		end
	elseif config.focus then
		vim.api.nvim_set_current_win(self.window)
		config.on_focus()
	end
end

---Closes the terminal split.
function Terminal:close()
	if vim.api.nvim_win_is_valid(self.window) then
		vim.api.nvim_win_hide(self.window)
		self.window = -1
	end
end

---Resets the terminal. This will restart the shell process.
function Terminal:reset()
	local open = self:is_open()
	local focus = self:is_focused()

	self:close()

	if vim.api.nvim_buf_is_valid(self.buffer) then
		vim.api.nvim_buf_delete(self.buffer, { force = true })
		self.buffer = -1
	end

	if open then
		self:open({ focus = focus })
	end
end

---@return `true` if the terminal split is currently open.
function Terminal:is_open()
	return vim.api.nvim_win_is_valid(self.window)
end

---@return `true` if the terminal split is currently open and focused.
function Terminal:is_focused()
	return vim.api.nvim_win_is_valid(self.window) and vim.api.nvim_get_current_win() == self.window
end

---Toggles between closed and opened terminal split.
---@param config BuildTerm.Terminal.Config? Configuration overrides.
function Terminal:toggle(config)
	if not self:is_open() then
		self:open(config)
	else
		self:close()
	end
end

---Runs the specified command in the terminal.
---@param command string[]|string The commands to run.
---@param config BuildTerm.Terminal.Config? Configuration overrides.
function Terminal:send(command, config)
	self:open(config)

	if vim.api.nvim_buf_is_valid(self.buffer) then
		local channel = vim.bo[self.buffer].channel

		if type(command) == "table" then
			for _, line in ipairs(command) do
				vim.fn.chansend(channel, line .. "\r\n")
			end
		else
			vim.fn.chansend(channel, command .. "\r\n")
		end

		-- self.ve to the end of the buffer (so that it auto-scrolls).
		if vim.api.nvim_win_is_valid(self.window) then
			local prev_win = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(self.window)
			vim.cmd("norm G")
			vim.api.nvim_set_current_win(prev_win)
		end
	end
end

---Clears the list of matched items.
function Terminal:clear_matches()
	self.cur_index = 0
	self.cur_mark = -1
	self.matches = {}
	self.index = {}

	if vim.api.nvim_buf_is_valid(self.buffer) then
		vim.api.nvim_buf_clear_namespace(self.buffer, self.namespace, 0, -1)
	end
end

---Clears the currently seleted item mark.
function Terminal:clear_selected_mark()
	if self.cur_mark >= 0 then
		vim.api.nvim_buf_del_extmark(self.buffer, self.namespace, self.cur_mark)
		self.cur_mark = -1
	end
end

---Returns the currently selected match.
---@return BuildTerm.Match? The currently selected match or nil.
function Terminal:get_current()
	return self.matches[self.cur_index]
end

---Returns the list of matches.
---@return BuildTerm.Match[] The list of matches.
function Terminal:get_matches()
	return self.matches
end

---Scans the match list in the given direction.
---@param config BuildTerm.NavConfig? Navigation configuration options.
---@param dir integer The scan direction.
---@return BuildTerm.Match? The found match or `nil`.
---@private
function Terminal:scan(config, dir)
	local def_config = {
		filter = function(_)
			return true
		end
	}

	config = vim.tbl_extend("force", def_config, config or {})

	local index = self.cur_index

	while true do
		index = index + dir

		if index <= 0 or index > #self.matches then
			return nil
		end

		if config.filter(self.matches[index]) then
			self.cur_index = index
			return self.matches[self.cur_index]
		end
	end
end

---Returns the current window ID.
function Terminal:get_window()
	return self.window
end

---Navigates to the next match.
---@param config BuildTerm.NavConfig? Navigation configuration options.
---@return BuildTerm.Match? The found match or `nil`.
function Terminal:goto_next(config)
	local match = self:scan(config, 1)
	self:goto_match(match, config)
	return match
end

---Navigates to the previous match.
---@param config BuildTerm.NavConfig? Navigation configuration options.
---@return BuildTerm.Match? The found match or `nil`.
function Terminal:goto_prev(config)
	local match = self:scan(config, -1)
	self:goto_match(match, config)
	return match
end

---Navigates and marks the given match.
---@param match BuildTerm.Match? The match to navigate to.
---@param config BuildTerm.NavConfig? Navigation configuration options.
function Terminal:goto_match(match, config)
	local def_config = {
		mark_source = true,
		goto_source = true,
		notify = function(index, total, item)
			if index then
				local message = item.data.message or ""
				vim.notify("[" .. index .. "/" .. total .. "] " .. message)
			else
				vim.notify("No item found", vim.log.levels.WARN)
			end
		end
	}

	config = vim.tbl_extend("force", def_config, config or {})

	if match then
		-- Mark should be set on all normally found matches.
		if not match.mark then
			error("Can not navigate to match without mark.")
		end

		local index = self.index[match.mark]
		config.notify(index, #self.matches, match)

		-- Retrieve the match position from the extmark.
		local result = vim.api.nvim_buf_get_extmark_by_id(self.buffer, self.namespace, match.mark, { details = true })
		local row = result[1]
		local details = result[3]

		if row and details then
			local location = { row, details.end_row }

			-- If requested, set the special "current item" mark at the same position.
			if config.mark_source then
				self:clear_selected_mark()

				if location then
					local mark_config = {
						end_row = location[2],
						hl_eol = true,
						line_hl_group = "Visual",
						hl_mode = "combine",
					}

					self.cur_mark = vim.api.nvim_buf_set_extmark(
					self.buffer,
					self.namespace,
					location[1],
					0,
					mark_config)
				end
			end

			-- Update the cursor position.
			if config.goto_source and location then
				self:open()
				vim.api.nvim_win_set_cursor(self.window, { location[1] + 1, 0 })
			end
		end
	else
		config.notify()
	end
end

return M
