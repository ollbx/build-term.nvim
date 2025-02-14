---@class BuildTerm.Config
---@field terminal BuildTerm.Terminal.Config? The terminal configuration.
---@field build BuildTerm.Builder.Config? The builder configuration.

local M = {
	_terminal = nil,
	_builder = nil,
	_commands = nil,
}

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

---Sets up the plugin.
---@param config BuildTerm.Config? The plugin configuration.
function M.setup(config)
	local def_config = {
		terminal = {},
		build = {},
	}

	config = vim.tbl_extend("force", def_config, config or {})

	local ok, err = pcall(function()
		local Terminal = require("build-term.terminal")
		local Builder = require("build-term.builder")

		M._terminal = Terminal.new(config.terminal)
		M._builder = Builder.new(M._terminal, config.build)
	end)

	if not ok then
		vim.notify(err --[[@as string]], vim.log.levels.ERROR)
	end

	M._commands = {
		show = function() M.show() end,
		open = function() M.open() end,
		close = function() M.close() end,
		reset = function() M.reset() end,
		toggle = function() M.toggle() end,
		send = function(args) M.send(table.concat(args, " ")) end,
		build = function(args) M.build(unpack(args)) end,
	}

	local match_ok, MatchList = pcall(require, "match-list")

	if match_ok then
		local match_commands = MatchList._commands

		-- Re-export commands from match-list.
		M._commands = vim.tbl_extend("force", M._commands, {
			["goto"] = match_commands["goto"],
			next = match_commands.next,
			prev = match_commands.prev,
			first = match_commands.first,
			last = match_commands.last,
			cancel = match_commands.cancel,
			select = function(args)
				local buffer = M._terminal:get_buffer()

				if vim.api.nvim_buf_is_valid(buffer) then
					if #args == 0 then
						MatchList.select_group(buffer)
					else
						MatchList.set_group(args, buffer)
					end
				end
			end,
			quickfix = match_commands.quickfix,
		})
	end

	local command = function(args)
		if #args.fargs == 0 then
			M.open()
		else
			local fun = M._commands[args.fargs[1]]
			local rest = {}

			for i=2,#args.fargs do
				table.insert(rest, args.fargs[i])
			end

			if fun then
				fun(rest)
			else
				vim.notify("Error: unrecognized command", vim.log.levels.ERROR)
			end
		end
	end

	vim.api.nvim_create_user_command("BuildTerm", command, {
		bar = true,
		nargs = "*",
		complete = function() return vim.tbl_keys(M._commands) end,
	})
end

---Opens the terminal window without changing focus to it.
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function M.show(config)
	M._terminal:show(config)
end

---Opens the terminal window and changes focus to it.
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function M.open(config)
	config = vim.tbl_extend("force", config or {}, { focus = true })
	M._terminal:show(config)
end

---Closes the terminal split.
function M.close()
	M._terminal:close()
end

---Resets the terminal. This will restart the shell process.
function M.reset()
	M._terminal:reset()
end

---@return `true` if the terminal split is currently open.
function M.is_open()
	return M._terminal:is_open()
end

---@return `true` if the terminal split is currently open and focused.
function M.is_focused()
	return M._terminal:is_focused()
end

---Toggles between closed and opened terminal split.
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function M.toggle(config)
	M._terminal:toggle(config)
end

---Runs the specified command in the terminal.
---@param command string[]|string The commands to run.
function M.send(command)
	M._terminal:send(command)
end

---Runs the first matching build command with the given args.
function M.build(...)
	M._builder:build(...)
end

return M
