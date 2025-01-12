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

---@class BuildTerm.Config
---@field match BuildTerm.GroupMatcher.Config? The group matcher configuration.
---@field terminal BuildTerm.Terminal.Config? The terminal configuration.
---@field view BuildTerm.View.Config? The view configuration.
---@field select_rebuild boolean? `true` to rebuild matches on select.

---@class BuildTerm.NavConfig
---@field filter BuildTerm.Terminal.FilterFun? A function to filter match results.
---@field notify BuildTerm.Terminal.NotifyFun? A function used to print a notification.
---@field update_view boolean? `true` to update the view window.
---@field mark_source boolean? `true` to mark the match source.
---@field goto_source boolean? `true` to navigate to the match source.
---@field goto_target boolean? `true` to navigate to the match target.

---@class BuildTerm.Match
---@field matcher BuildTerm.Matcher? The matcher that produced the result.
---@field offset integer? The match offset.
---@field length integer The length of the match.
---@field mark integer? The extmark ID in the terminal buffer.
---@field type string The type of the match.
---@field data { string: string } The match data.

local M = {}

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

---Sets up the plugin.
---@param config BuildTerm.Config? The plugin configuration.
function M.setup(config)
	local def_config = {
		match = nil,
		terminal = nil,
		view = nil,
		select_rebuild = true,
	}

	config = vim.tbl_extend("force", def_config, config or {})
	M.config = config

	local GroupMatcher = require("build-term.group_matcher")
	local Terminal = require("build-term.terminal")
	local View = require("build-term.view")
	local Builder = require("build-term.builder")

	local ok, err = pcall(function()
		M.matcher = GroupMatcher.new(config.match)
		M.terminal = Terminal.new(M.matcher, config.terminal)
		M.view = View.new(config.view)
		M.builder = Builder.new(M.matcher, M.terminal, config.build)
	end)

	if not ok then
		vim.notify(err --[[@as string]], vim.log.levels.ERROR)
	end

	local complete = function()
		return {
			"toggle",
			"show",
			"open",
			"goto",
			"close",
			"reset",
			"send",
			"next",
			"prev",
			"select",
			"select-ui",
			"build",
			"quickfix",
		}
	end

	local function make_filter(args)
		local types = {}

		if #args == 0 then
			return function() return true end
		end

		for _, arg in ipairs(args) do
			types[arg] = true
		end

		return function(item)
			return types[item.type] ~= nil
		end
	end

	local command = function(args)
		local cmd = args.fargs[1]

		if cmd == "toggle" then
			M.toggle()
		elseif cmd == "show" then
			M.show()
		elseif cmd == "open" then
			M.open()
		elseif cmd == "goto" then
			M.goto_below_cursor()
		elseif cmd == "close" then
			M.close()
		elseif cmd == "reset" then
			M.reset()
		elseif cmd == "send" then
			M.send(string.sub(args.args, 5))
		elseif cmd == "next" then
			table.remove(args.fargs, 1)
			M.goto_next({ filter = make_filter(args.fargs) })
		elseif cmd == "prev" then
			table.remove(args.fargs, 1)
			M.goto_prev({ filter = make_filter(args.fargs) })
		elseif cmd == "select" then
			table.remove(args.fargs, 1)
			M.select(unpack(args.fargs))
		elseif cmd == "select-ui" then
			M.select_ui()
		elseif cmd == "build" then
			table.remove(args.fargs, 1)
			M.build(unpack(args.fargs))
		elseif cmd == "quickfix" then
			M.send_to_quickfix()
		else
			vim.notify("Error: unrecognized command", vim.log.levels.ERROR)
		end
	end

	vim.api.nvim_create_user_command("BuildTerm", command, { nargs = "+", complete = complete })
end

---Opens the terminal window without changing focus to it.
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function M.show(config)
	M.terminal:show(config)
end

---Opens the terminal window and changes focus to it.
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function M.open(config)
	config = vim.tbl_extend("force", config or {}, { focus = true })
	M.terminal:show(config)
end

---Closes the terminal split.
function M.close()
	M.terminal:close()
end

---Resets the terminal. This will restart the shell process.
function M.reset()
	M.terminal:reset()
end

---@return `true` if the terminal split is currently open.
function M.is_open()
	return M.terminal:is_open()
end

---@return `true` if the terminal split is currently open and focused.
function M.is_focused()
	return M.terminal:is_focused()
end

---Toggles between closed and opened terminal split.
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function M.toggle(config)
	M.terminal:toggle(config)
end

---Runs the specified command in the terminal.
---@param command string[]|string The commands to run.
function M.send(command)
	M.terminal:send(command)
end

---Clears the list of matched items.
function M.clear_matches()
	M.terminal:clear_matches()
end

---Clears the currently seleted item mark.
function M.clear_selected_mark()
	M.terminal:clear_selected_mark()
end

---Returns the currently selected match.
---@return BuildTerm.Match? The currently selected match or nil.
function M.get_current()
	return M.terminal:get_current()
end

---Returns the index of the currently selected match.
---@return integer The currently selected index or 0 (if none is selected).
function M.get_current_index()
	return M.terminal:get_current_index()
end

---Returns the list of matches.
---@return BuildTerm.Match[] The list of matches.
function M.get_matches()
	return M.terminal:get_matches()
end

---Navigates to a new match.
---@param config BuildTerm.NavConfig? Navigation configuration options.
---@param fun fun(): BuildTerm.Match? Function to navigate to a new match.
---@return BuildTerm.Match? The found match or `nil`.
local function navigate(config, fun)
	local def_config = {
		update_view = true,
		goto_target = true,
	}

	config = vim.tbl_extend("force", def_config, config or {})

	if config.update_view then
		local terminal_win = M.terminal:get_window()
		local current_win = vim.api.nvim_get_current_win()

		if current_win ~= terminal_win then
			M.view:set_window(current_win)
		end
	end

	local match = fun()

	if config.goto_target then
		M.view:goto_match(match)
	end

	return match
end

---Returns the match below the cursor in the terminal window.
---@return BuildTerm.Match? # The match or `nil` if none was found.
function M.get_match_below_cursor()
	return M.terminal:get_match_below_cursor()
end

---Navigates to the match below the cursor.
---@param config BuildTerm.NavConfig? Navigation configuration options.
---@return BuildTerm.Match? The found match or `nil`.
function M.goto_below_cursor(config)
	return navigate(config, function()
		return M.terminal:goto_below_cursor(config)
	end)
end

---Navigates to the next match.
---@param config BuildTerm.NavConfig? Navigation configuration options.
---@return BuildTerm.Match? The found match or `nil`.
function M.goto_next(config)
	return navigate(config, function()
		return M.terminal:goto_next(config)
	end)
end

---Navigates to the previous match.
---@param config BuildTerm.NavConfig? Navigation configuration options.
---@return BuildTerm.Match? The found match or `nil`.
function M.goto_prev(config)
	return navigate(config, function()
		return M.terminal:goto_prev(config)
	end)
end

---Navigates and marks the given match.
---@param match BuildTerm.Match? The match to navigate to.
---@param config BuildTerm.NavConfig? Navigation configuration options.
function M.goto_match(match, config)
	return navigate(config, function()
		return M.terminal:goto_match(match, config)
	end)
end

---Returns the currently selected match groups.
function M.get_selected_groups()
	return M.matcher:get_selected()
end

---Returns all available match groups in order.
function M.get_groups()
	return M.matcher:get_groups()
end

---Sets the enabled match groups.
function M.select(...)
	M.matcher:select(...)

	if M.config.select_rebuild then
		M.rebuild_matches()
	end
end

---Selects the match group using the UI.
function M.select_ui()
	vim.ui.select(M.get_groups(), {
		prompt = "Select match group:"
	}, function(choice)
		if choice then
			M.select(choice)
		end
	end)
end

---Rebuilds the list of matches with the selected groups.
function M.rebuild_matches()
	M.terminal:rebuild_matches()
end

---Runs the first matching build command with the given args.
function M.build(...)
	M.builder:build(...)
end

---Sends the match list to the quickfix.
---@param config BuildTerm.Terminal.QuickFixConfig? Configuration options.
function M.send_to_quickfix(config)
	M.terminal:send_to_quickfix(config)
end

---Tests a match expression against the given line.
---@param config BuildTerm.Matcher.Config The match config.
---@param line string The line to match against.
---@return BuildTerm.Match? The match or `nil`.
function M.test_match(config, line)
	return require("build-term.matcher").new(config):match({ line }, 1)
end

return M
