local M = {}

---The minimum update timeout between UI updates.
local UPDATE_TIMEOUT = 25

---@class BuildTerm.Tracker.Buffer Settings for a tracked buffer.
---@field group string? The match group to use or `nil` to use the global one.

---@class BuildTerm.Tracker.Hooks Hooks for the tracker.
---@field update fun(visible_matches: [BuildTerm.Match]) Called after update.

---@class BuildTerm.Tracker Tracks and highlights matches in buffers.
---@field namespace integer The namespace used for extmarks.
---@field buffers { integer: BuildTerm.Tracker.Buffer } The buffers tracked.
---@field groups { string: [BuildTerm.Scanner] } The scanner groups available.
---@field group string The currently selected group.
---@field matches [BuildTerm.Match]? The cached list of matches.
---@field visible_matches [BuildTerm.Match] The list of visible matches.
---@field scheduled boolean `true` if an update has been scheduled.
---@field last_update integer The timestamp of the last update.
---@field current integer The currently selected index.
---@field hooks BuildTerm.Tracker.Hooks Hook functions.
local Tracker = {}
Tracker.__index = Tracker

---Creates a new tracker.
---@return BuildTerm.Tracker tracker The tracker.
function M.new()
	local ui = {
		namespace = vim.api.nvim_create_namespace(""),
		buffers = {},
		groups = {},
		group = "default",
		matches = nil,
		visible_matches = {},
		scheduled = false,
		last_update = vim.uv.now(),
		current = 0,
		hooks = {
			update = function() end,
		}
	}

	vim.api.nvim_create_autocmd("WinScrolled", {
		--pattern = {}
		callback = function()
			local windows = vim.fn.getwininfo()
			local changes = vim.v.event

			-- Schedule an update if any of the scrolled windows show our buffer.
			for _, window in ipairs(windows) do
				if ui.buffers[window.bufnr] and changes[tostring(window.winid)] then
					ui:schedule_update()
					break
				end
			end
		end
	})

	setmetatable(ui, Tracker)
	return ui
end

---Updates the match groups.
---@param groups { string: [BuildTerm.Scanner] } The match groups.
function Tracker:define_groups(groups)
	self.groups = groups
	self:schedule_update()
end

---Updates a specific match group.
---@param name string The name of the match group to set.
---@param group [BuildTerm.Scanner] The match group.
function Tracker:define_group(name, group)
	self.groups[name] = group
	self:schedule_update()
end

---Returns the groups configured in the tracker.
---@return [string] groups The configured groups.
function Tracker:list_groups()
	local groups = {}

	for group, _ in pairs(self.groups) do
		table.insert(groups, group)
	end

	table.sort(groups, function(a, b)
		if a == "default" then
			-- Default is smaller than everything except for itself.
			return b ~= a
		else
			return a < b
		end
	end)

	return groups
end

---Sets the match group to use for matching.
---@param name string? The name of the match group to use or `nil` for `"default"`.
---@param global boolean? Specify `false` to set the match group for the local buffer only.
function Tracker:set_group(name, global)
	if global == nil or global == true then
		self.group = name or "default"
	else
		local buffer = vim.api.nvim_get_current_buf()
		local config = self.buffers[buffer]

		if config then
			config.group = name
		end
	end

	self:schedule_update()
end

---Attaches the tracker to the given buffer.
---@param buffer integer? The buffer to attach to. `nil` for the current buffer.
function Tracker:attach(buffer)
	if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
		buffer = vim.api.nvim_get_current_buf()
	end

	if not self.buffers[buffer] then
		self.buffers[buffer] = {}

		-- Schedule an update if our buffer changes.
		local ui = self

		vim.api.nvim_buf_attach(buffer, false, {
			on_reload = function()
				if ui.buffers[buffer] then
					ui:schedule_update()
					ui.matches = nil
				else
					-- detach
					return true
				end
			end,
			on_lines = function()
				if ui.buffers[buffer] then
					ui:schedule_update()
					ui.matches = nil
				else
					-- detach
					return true
				end
			end,
		})

		ui:schedule_update()
		ui.matches = nil
	end
end

---Detaches the tracker from the given buffer.
---@param buffer integer? The buffer to attach to. `nil` for the current buffer.
function Tracker:detach(buffer)
	if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
		buffer = vim.api.nvim_get_current_buf()
	end

	if self.buffers[buffer] then
		self.buffers[buffer] = nil
		self:schedule_update()
	end
end

---Schedules an UI update to run in the near future.
function Tracker:schedule_update()
	-- This will limit the amount of updates to only one update per `update_timeout`.
	if not self.scheduled then
		local ui = self
		self.scheduled = true

		local now = vim.uv.now()
		local elapsed = now - self.last_update
		local wait = UPDATE_TIMEOUT - math.min(elapsed, UPDATE_TIMEOUT)

		vim.defer_fn(function()
			ui:update()
			ui.scheduled = false
			ui.last_update = now
		end, wait)
	end
end

---Removes any invalid buffers from the tracked buffer list.
function Tracker:check_buffers()
	local update = false

	for buffer, _ in pairs(self.buffers) do
		if not vim.api.nvim_buf_is_valid(buffer) then
			update = true
			break
		end
	end

	if update then
		local buffers = {}

		for buffer, config in pairs(self.buffers) do
			if vim.api.nvim_buf_is_valid(buffer) then
				buffers[buffer] = config
			end
		end

		self.buffers = buffers
	end
end

---Creates extmarks for matches in any part of the buffer that is currently
---visible through a window.
function Tracker:update()
	-- Remove old buffers.
	self:check_buffers()

	-- Clear all existing extmarks.
	for buffer, _ in pairs(self.buffers) do
		vim.api.nvim_buf_clear_namespace(buffer, self.namespace, 0, -1)
	end

	-- Collect all the windows that show our buffers.
	local windows = self:get_windows()

	-- Figure out the longest multi-line error we can match.
	local lines = 1

	for _, scanner in ipairs(self.groups) do
		lines = math.max(lines, scanner:get_lines())
	end

	local highlight = {
		error = "DiagnosticSignError",
		warning = "DiagnosticSignWarn",
		info = "DiagnosticSignInfo",
		hint = "DiagnosticSignHint",
	}

	self.visible_matches = {}

	for _, window in ipairs(windows) do
		-- Scan the visible area of the buffer for the given window.
		local first = math.max(1, window.topline - lines - 1)
		local last = window.botline
		local config = self.buffers[window.bufnr]
		local group = config.group or self.group
		local scanners = self.groups[group] or {}

		for _, scanner in ipairs(scanners) do
			local matches = scanner:scan(window.bufnr, first, last)

			for _, match in ipairs(matches) do
				local type = match.data["type"] or "hint"

				-- Create extmarks.
				vim.api.nvim_buf_set_extmark(window.bufnr, self.namespace, match.lnum - 1, 0, {
					end_row = match.lnum + match.lines - 2,
					hl_eol = true,
					hl_mode = "combine",
					sign_text = string.upper(string.sub(type, 1, 1)),
					sign_hl_group = highlight[type],
					line_hl_group = highlight[type],
				})

				table.insert(self.visible_matches, match)
			end
		end
	end

	self.hooks.update(self.visible_matches)
end

---Returns all windows that currently contain one of the tracked buffers.
---@return [vim.fn.getwininfo.ret.item] windows The window list.
function Tracker:get_windows()
	-- Collect all the windows that show our buffer.
	local windows = {}

	for _, window in ipairs(vim.fn.getwininfo()) do
		if self.buffers[window.bufnr] then
			table.insert(windows, window)
		end
	end

	return windows
end

---Returns all currently tracked matches.
---@return [BuildTerm.Match] matches The matches list.
function Tracker:get_matches()
	if not self.matches then
		self.matches = {}

		for buffer, _ in pairs(self.buffers) do
			local config = self.buffers[buffer]
			local group = config.group or self.group
			local scanners = self.groups[group] or {}

			for _, scanner in ipairs(scanners) do
				local matches = scanner:scan(buffer)

				for _, match in ipairs(matches) do
					table.insert(self.matches, match)
				end
			end
		end

		table.sort(self.matches, function(a, b)
			if a.buffer ~= b.buffer then
				return a.buffer < b.buffer
			else
				return a.lnum < b.lnum
			end
		end)
	end

	return self.matches
end

---Returns all currently visible matches.
---@return [BuildTerm.Match] matches The matches list.
function Tracker:get_visible_matches()
	return self.visible_matches
end

---Scrolls any open views to the given match.
---@param match BuildTerm.Match The match to scroll to.
---@param focus boolean? `true` to focus a window containing the match.
function Tracker:goto_match(match, focus)
	local windows = self:get_windows()

	for _, window in ipairs(windows) do
		if window.bufnr == match.buffer then
			vim.api.nvim_win_set_cursor(window.winid, { match.lnum, 0 })

			if focus then
				vim.api.nvim_set_current_win(window.winid)
			end
		end
	end
end

---Moves the current item back or forward.
---@param amount integer The amount to skip ahead / backwards.
---@param focus boolean? `true` to focus a window containing the match.
function Tracker:skip(amount, focus)
	self:get_matches()

	local new_index = self.current + amount

	if new_index >= 1 and new_index <= #self.matches then
		local match = self.matches[new_index]
		self.current = new_index
		self:goto_match(match, focus)
	else
		vim.notify("No more matches found")
	end
end

---Moves to the next item.
---@param focus boolean? `true` to focus a window containing the match.
function Tracker:next(focus)
	self:skip(1, focus)
end

---Moves to the previous item.
---@param focus boolean? `true` to focus a window containing the match.
function Tracker:prev(focus)
	self:skip(-1, focus)
end

---Moves to the first item.
---@param focus boolean? `true` to focus a window containing the match.
function Tracker:first(focus)
	self:get_matches()

	if #self.matches > 0 then
		local match = self.matches[1]
		self.current = 1
		self:goto_match(match, focus)
	else
		vim.notify("No matches found")
	end
end

---Moves to the last item.
---@param focus boolean? `true` to focus a window containing the match.
function Tracker:last(focus)
	self:get_matches()

	if #self.matches > 0 then
		local match = self.matches[#self.matches]
		self.current = #self.matches
		self:goto_match(match, focus)
	else
		vim.notify("No matches found")
	end
end

---Sets the update hook function.
---The update hook is called after every UI update.
function Tracker:set_update_hook(fun)
	self.hooks.update = fun
end

return M
