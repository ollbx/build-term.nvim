--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@alias BuildTerm.Terminal.WindowConfig vim.api.keyset.win_config|(fun(): vim.api.keyset.win_config)|nil
---@alias BuildTerm.Terminal.NotifyFun fun(index: integer?, total: integer?, match: BuildTerm.Match?)
---@alias BuildTerm.Terminal.FilterFun fun(match: BuildTerm.Match): boolean?
---@alias BuildTerm.Terminal.ExtMarkConfigFun fun(BuildTerm.Match): vim.api.keyset.set_extmark
---@alias BuildTerm.Terminal.ShellFun fun(): string?

---@class BuildTerm.Terminal.Config:BuildTerm.Terminal.ShowConfig
---@field shell (BuildTerm.Terminal.ShellFun|string)? Specifies the shell command to execute. `nil` for default.
---@field extmark_config BuildTerm.Terminal.ExtMarkConfigFun? Extmark config function.

---@class BuildTerm.Terminal.ShowConfig
---@field focus boolean? `true` to move the cursor into the terminal on open.
---@field window BuildTerm.Terminal.WindowConfig The window configuration.
---@field init_buffer fun()? Terminal buffer initialization hook function.
---@field init_window fun()? Terminal window initialization hook function.
---@field on_focus fun()? Terminal window focus hook function.

---@class BuildTerm.Terminal.QuickFixConfig
---@field convert fun(BuildTerm.Match): table QuickFix item constructor.
---@field open_quickfix boolean `true` to open the quickfix.
---@field close_terminal boolean `true` to close the terminal.

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local M = {}

---@class BuildTerm.Terminal
---@field buffer integer The terminal buffer (or -1 if uninitialized).
---@field window integer The terminal window (or -1 if hidden).
---@field matcher BuildTerm.GroupMatcher The group matcher to use.
---@field matches { integer: BuildTerm.Match } The list of matches (by mark ID).
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
		cur_index = 0,
		cur_mark = -1,
		namespace = vim.api.nvim_create_namespace(""),
		config = vim.tbl_extend("force", def_config, config or {}),
	}

	setmetatable(terminal, Terminal)
	return terminal
end

---Gets all currently known matches.
---@return { integer: BuildTerm.Match } The list of matches (by offset).
function Terminal:get_matches()
	local matches = {}
	self:visit_range(0, -1, function(match) table.insert(matches, match) end)
	return matches
end

---Gets all currently known matches in the given line range in order.
---_Note_: multi-line matches are set to the first line they match at.
---@param first integer The first line to scan (0-based index).
---@param last integer The last line to scan (0-based index).
---@param visit fun(match: BuildTerm.Match, row: integer) The visitor function.
function Terminal:visit_range(first, last, visit)
	if not vim.api.nvim_buf_is_valid(self.buffer) then
		return {}
	end

	local matches = {}

	-- Find all existing matches that overlap the changed area.
	local old_marks = vim.api.nvim_buf_get_extmarks(
		self.buffer,
		self.namespace,
		{ first, 0 },
		{ last, 0 },
		{})

	for _, mark in ipairs(old_marks) do
		if mark ~= self.cur_mark then
			local mark_id = mark[1]
			local row = mark[2]
			local match = self.matches[mark_id]

			if match then
				visit(match, row)
			else
				vim.api.nvim_buf_del_extmark(self.buffer, self.namespace, mark_id)
				self.matches[mark_id] = nil
			end
		end
	end

	return matches
end

---Gets all currently known matches in the given line range as a map.
---_Note_: multi-line matches are set to the first line they match at.
---@param first integer The first line to scan (0-based index).
---@param last integer The last line to scan (0-based index).
---@return { integer: BuildTerm.Match } # The matches (by row).
function Terminal:visit_range_as_map(first, last)
	local matches = {}
	self:visit_range(first, last, function(match, row) matches[row] = match end)
	return matches
end

---Scans for matches in the given line range in order.
---_Note_: multi-line matches are set to the first line they match at.
---@param first integer The first line to scan (0-based index).
---@param last integer The last line to scan (0-based index).
---@param visit fun(match: BuildTerm.Match, row: integer) The visitor function.
function Terminal:scan_range(first, last, visit)
	if not vim.api.nvim_buf_is_valid(self.buffer) then
		return {}
	end

	-- Extend the line end to find multi-line matches.
	local context = self.matcher:get_context()

	if first < 0 then
		first = 0
	end

	if last >= 0 then
		last = last + context
	end

	-- Retrieve the changed lines and match on them.
	local lines = vim.api.nvim_buf_get_lines(self.buffer, first, last, false)

	for rel_offset, match in pairs(self.matcher:scan(lines)) do
		local row = first + rel_offset - 1

		if row >= first and (row <= last or last < 0) then
			visit(match, row)
		end
	end
end

---Scans for matches in the given line range as a map.
---_Note_: multi-line matches are set to the first line they match at.
---@param first integer The first line to scan (0-based index).
---@param last integer The last line to scan (0-based index).
---@return { integer: BuildTerm.Match } # The matches (by row).
function Terminal:scan_range_as_map(first, last)
	local matches = {}
	self:scan_range(first, last, function(match, row) matches[row] = match end)
	return matches
end

---Handles new output on the terminal buffer.
---@param first integer The first line to scan (0-based index).
---@param last integer The last line to scan (0-based index).
function Terminal:rescan_lines(first, last)
	if not vim.api.nvim_buf_is_valid(self.buffer) then
		return
	end

	vim.print("rescan " .. first .. " " .. last)

	-- Extened the scan area so that it can include multi-line matches that start
	-- before `first`, but that that may still be affected.
	local context = self.matcher:get_context()
	first = math.max(0, first - context)

	-- Get the known matches in the area and then rescan the area for new matches.
	local old_matches = self:visit_range_as_map(first, last)
	local new_matches = self:scan_range_as_map(first, last)

	-- Find old matches that are no longer in the area and remove them.
	for offset, old_match in pairs(old_matches) do
		local new_match = new_matches[offset]

		if not new_match then
			vim.api.nvim_buf_del_extmark(self.buffer, self.namespace, old_match.mark)
			self.matches[old_match.mark] = nil
		end
	end

	-- Find new or updated matches.
	for offset, new_match in pairs(new_matches) do
		local old_match = old_matches[offset]

		local config = {
			end_row = offset + new_match.length - 1,
			hl_eol = true,
			sign_text = "H",
			sign_hl_group = "DiagnosticSignHint",
			hl_mode = "combine",
		}

		if new_match.type == "err" or new_match.type == "error" then
			config.sign_text = "E"
			config.sign_hl_group = "DiagnosticSignError"
		elseif new_match.type == "warn" or new_match.type == "warning" then
			config.sign_text = "W"
			config.sign_hl_group = "DiagnosticSignWarn"
		elseif new_match.type == "info" then
			config.sign_text = "I"
			config.sign_hl_group = "DiagnosticSignInfo"
		elseif new_match.type == "debug" then
			config.sign_text = "D"
			config.sign_hl_group = "DiagnosticSignInfo"
		end

		config.line_hl_group = config.sign_hl_group

		if self.config.extmark_config then
			local overrides = self.config.extmark_config(match)
			config = vim.tbl_extend("force", config, overrides)
		end

		-- If there is an old match at the offset, we replace it.
		if old_match then
			config.id = old_match.mark
			self.matches[old_match.mark] = nil
		end

		-- Create the new mark / update the existing one.
		new_match.mark = vim.api.nvim_buf_set_extmark(
			self.buffer,
			self.namespace,
			offset,
			0,
			config)

		self.matches[new_match.mark] = new_match
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
			local shell = config.shell

			if type(shell) == "function" then
				shell = config.shell()
			end

			vim.cmd.terminal(shell)

			vim.api.nvim_buf_attach(self.buffer, false, {
				on_lines = function(_, _, _, first, last)
					self:rescan_lines(first, last)
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
		local newline = "\n"

		if vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1 then
			newline = "\r\n"
		end

		if type(command) == "table" then
			for _, line in ipairs(command) do
				vim.fn.chansend(channel, line .. newline)
			end
		else
			vim.fn.chansend(channel, command .. newline)
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
	self:rescan_lines(0, -1)
end

---Clears the list of matched items.
function Terminal:clear_matches()
	self.cur_index = 0
	self.cur_mark = -1
	self.matches = {}

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
				vim.notify("No match found", vim.log.levels.WARN)
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

---Sends the match list to the quickfix.
---@param config BuildTerm.Terminal.QuickFixConfig? Configuration options.
function Terminal:send_to_quickfix(config)
	local def_config = {
		convert = function(match)
			return {
				filename = match.data.file,
				lnum = match.data.lnum,
				col = match.data.col,
				text = match.data.message,
				type = string.sub(match.type, 1, 1),
			}
		end,
		open_quickfix = true,
		close_terminal = true,
	}

	config = vim.tbl_extend("force", def_config, config or {})
	local items = {}

	for _, match in ipairs(self.matches) do
		local item = config.convert(match)

		if item then
			table.insert(items, item)
		end
	end

	vim.fn.setqflist(items, ' ')

	if config.open_quickfix then
		vim.cmd.copen()
	end

	if config.close_terminal then
		self:close()
	end
end

return M
