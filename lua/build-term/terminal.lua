--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@alias BuildTerm.Terminal.WindowConfig vim.api.keyset.win_config|(fun(): vim.api.keyset.win_config)|nil
---@alias BuildTerm.Terminal.NotifyFun fun(index: integer?, total: integer?, match: BuildTerm.Match?)
---@alias BuildTerm.Terminal.FilterFun fun(match: BuildTerm.Match): boolean?
---@alias BuildTerm.Terminal.ExtMarkConfigFun fun(BuildTerm.Match): vim.api.keyset.set_extmark

---@class BuildTerm.Terminal.Config:BuildTerm.Terminal.ShowConfig
---@field shell string? Specifies the shell command to execute. `nil` for default.
---@field extmark_config BuildTerm.Terminal.ExtMarkConfigFun? Extmark config function.

---@class BuildTerm.Terminal.ShowConfig
---@field focus boolean? `true` to move the cursor into the terminal on open.
---@field window BuildTerm.Terminal.WindowConfig The window configuration.
---@field init_buffer fun()? Terminal buffer initialization hook function.
---@field init_window fun()? Terminal window initialization hook function.
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
		shell = nil,
		-- Default window is 25% on the bottom.
		window = function()
			return {
				split = "below",
				height = math.floor(vim.o.lines / 4),
			}
		end,
		-- Default init function sets up keymaps.
		init_buffer = function(buffer)
			vim.keymap.set("n", "<cr>", "<cmd>:BuildTerm goto<cr>", { buffer = buffer })
		end,
		-- Default init function disables line numbers.
		init_window = function()
			vim.opt_local.nu = false
			vim.opt_local.relativenumber = false
		end,
		-- Default focus function enters insert mode.
		on_focus = function()
			vim.cmd.startinsert()
		end,
		-- Extmark config overrides.
		extmark_config = nil,
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
	if not vim.api.nvim_buf_is_valid(self.buffer) then
		return
	end

	-- Extend the area by the context required.
	local context = self.matcher:get_context()
	first = math.max(0, first - context)

	if last < 0 then
		last = -1
	else
		last = last + context
	end

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

		if match.type == "err" or match.type == "error" then
			config.sign_text = "E"
			config.sign_hl_group = "DiagnosticSignError"
		elseif match.type == "warn" or match.type == "warning" then
			config.sign_text = "W"
			config.sign_hl_group = "DiagnosticSignWarn"
		elseif match.type == "info" then
			config.sign_text = "I"
			config.sign_hl_group = "DiagnosticSignInfo"
		elseif match.type == "debug" then
			config.sign_text = "D"
			config.sign_hl_group = "DiagnosticSignInfo"
		end

		config.line_hl_group = config.sign_hl_group

		if self.config.extmark_config then
			local overrides = self.config.extmark_config(match)
			config = vim.tbl_extend("force", config, overrides)
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
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function Terminal:show(config)
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
		config.init_window(self.window)

		-- If the buffer is not a terminal yet, enter terminal mode.
		if vim.bo[self.buffer].buftype ~= "terminal" then
			vim.cmd.terminal(config.shell)

			vim.api.nvim_buf_attach(self.buffer, false, {
				on_lines = function(_, _, _, first, last)
					self:handle_output(first, last)
				end
			})

			config.init_buffer(self.buffer)
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
		self:show({ focus = focus })
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
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function Terminal:toggle(config)
	if not self:is_open() then
		self:show(config)
	else
		self:close()
	end
end

---Runs the specified command in the terminal.
---@param command string[]|string The commands to run.
---@param config BuildTerm.Terminal.Config? Configuration overrides.
function Terminal:send(command, config)
	self:show(config)

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

---Rebuilds the list of matches with the selected groups.
function Terminal:rebuild_matches()
	self:clear_matches()
	self:handle_output(0, -1)
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

---Returns the index of the currently selected match.
---@return integer The currently selected index or 0 (if none is selected).
function Terminal:get_current_index()
	return self.cur_index
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
			return self.matches[index]
		end
	end
end

---Returns the current window ID.
function Terminal:get_window()
	return self.window
end

---Returns the match below the cursor in the terminal window.
---@return BuildTerm.Match? # The match or `nil` if none was found.
function Terminal:get_match_below_cursor()
	local cursor = vim.api.nvim_win_get_cursor(self.window)

	-- Cursor is (1,0)-based indexing, extmark (0,0)-based.
	local row = cursor[1] - 1

	local found = vim.api.nvim_buf_get_extmarks(
		self.buffer,
		self.namespace,
		{ row, 0 },
		{ row, 0 },
		{ overlap = true })

	if #found > 0 then
		local mark = found[1][1]
		local index = self.index[mark]

		if index then
			return self.matches[index]
		else
			return nil
		end
	else
		return nil
	end
end

---Navigates to the match below the cursor.
---@param config BuildTerm.NavConfig? Navigation configuration options.
---@return BuildTerm.Match? The found match or `nil`.
function Terminal:goto_below_cursor(config)
	local match = self:get_match_below_cursor()

	if match then
		-- We do not need to go to the source. We are already there.
		config = vim.tbl_extend("force", config or {}, { goto_source = false })
		self:goto_match(match, config)
	end

	return match
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
		self.cur_index = index

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
				self:show()
				vim.api.nvim_win_set_cursor(self.window, { location[1] + 1, 0 })
			end
		end
	else
		config.notify()
	end
end

return M
