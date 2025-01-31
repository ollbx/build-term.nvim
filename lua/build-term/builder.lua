local M = {}

---@alias BuildTerm.Builder.CommandFun fun(...): string[]|string
---@alias BuildTerm.Builder.TriggerFun fun(): boolean
---@alias BuildTerm.Builder.PrepareFun fun(): boolean
---
---@class BuildTerm.Builder.Config
---@field commands BuildTerm.Builder.CommandConfig[] The builder commands.
---@field prepare BuildTerm.Builder.PrepareFun? Function called to prepare the build.
---@field save_before_build boolean `true` to save all files before the build.
---
---@class BuildTerm.Builder.CommandConfig
---@field priority integer? The selection priority.
---@field trigger string|BuildTerm.Builder.TriggerFun The build command trigger.
---@field select string[]? The groups to select.
---@field reset boolean? `true` to reset the terminal before the build.
---@field command string|string[]|BuildTerm.Builder.CommandFun

---@class BuildTerm.Builder.Command
---@field priority integer The selection priority.
---@field check fun(): boolean Function to check the build trigger.
---@field match string|string[]|nil The match groups to select.
---@field clear boolean `true` to clear the matches before the build.
---@field reset boolean `true` to reset the terminal before the build.
---@field command BuildTerm.Builder.CommandFun The command builder.

---@class BuildTerm.Builder
---@field config BuildTerm.Builder.Config The build configuration.
---@field commands BuildTerm.Builder.Command[] The build commands.
---@field terminal BuildTerm.Terminal The terminal to use.
---@field private __index any
local Builder = {}
Builder.__index = Builder

---Creates a build command check function.
local function to_check(config)
	if type(config) == "string" then
		return function()
			return vim.fn.filereadable(config) == 1
		end
	elseif type(config) == "function" then
		return config
	else
		return nil
	end
end

---Creates a command builder function.
local function to_command(config)
	if type(config) == "string" then
		return function(...)
			return table.concat({ config, ... }, " ")
		end
	elseif type(config) == "table" then
		return function(...)
			local lines = {}

			for i, line in ipairs(config) do
				if i == #config then
					table.insert(lines, table.concat({ line, ... }, " "))
				else
					table.insert(lines, line)
				end
			end

			return lines
		end
	elseif type(config) == "function" then
		return config
	else
		return nil
	end
end

---Creates a new builder.
---@param terminal BuildTerm.Terminal The terminal to use.
---@param config BuildTerm.Builder.Config? The builder config to use.
---@return BuildTerm.Builder
function M.new(terminal, config)
	local def_config = {
		commands = {},
		prepare = nil,
		save_before_build = false,
	}

	config = vim.tbl_extend("force", def_config, config or {})

	local commands = {}

	for _, build_config in ipairs(config.commands) do
		local trigger = to_check(build_config.trigger)
		local command = to_command(build_config.command)

		if not trigger or not command then
			error("Invalid build configuration " .. vim.inspect(build_config))
		end

		table.insert(commands, {
			check = trigger,
			command = command,
			match = build_config.match,
			priority = build_config.priority or 0,
			reset = build_config.reset or true,
			clear = build_config.clear or true,
		})
	end

	-- Sort by priority.
	table.sort(commands, function(a, b)
		return a.priority > b.priority
	end)

	local builder = {
		config = config,
		commands = commands,
		terminal = terminal,
	}

	setmetatable(builder, Builder)
	return builder
end

---Runs the first build command that is triggered.
---Arguments are passed through to the build function.
function Builder:build(...)
	for _, command in ipairs(self.commands) do
		if command.check() then
			-- Save all files if requested.
			if self.config.save_before_build then
				vim.cmd("wa")
			end

			-- Run the prepare function.
			if self.config.prepare then
				if not self.config.prepare() then
					return
				end
			end

			-- Reset the terminal if requested.
			if command.reset then
				self.terminal:reset()
			end

			-- Issue the build commands.
			self.terminal:send(command.command(...))

			-- Change the selected match groups.
			if command.match then
				local buffer = self.terminal:get_buffer()

				if vim.api.nvim_buf_is_valid(buffer) then
					local ok, MatchList = pcall(require, "match-list")

					if ok then
						MatchList.attach(buffer, command.match)
					end
				end
			end

			return
		end
	end

	vim.notify("No matching builder was found.", vim.log.levels.WARN)
end

return M
