local M = {}

---@alias BuildTerm.Builder.CommandFun fun(...): string[]|string
---@alias BuildTerm.Builder.Config BuildTerm.Builder.CommandConfig[]
---@alias BuildTerm.Builder.TriggerFun fun(): boolean
---
---@class BuildTerm.Builder.CommandConfig
---@field priority integer? The selection priority.
---@field trigger string|BuildTerm.Builder.TriggerFun The build command trigger.
---@field select string[]? The groups to select.
---@field clear boolean? `true` to clear the matches before the build.
---@field reset boolean? `true` to reset the terminal before the build.
---@field command string|string[]|BuildTerm.Builder.CommandFun

---@class BuildTerm.Builder.Command
---@field priority integer The selection priority.
---@field trigger fun(): boolean Function to trigger a builder.
---@field select string[]? The groups to select.
---@field clear boolean `true` to clear the matches before the build.
---@field reset boolean `true` to reset the terminal before the build.
---@field command BuildTerm.Builder.CommandFun The command builder.

---@class BuildTerm.Builder
---@field commands BuildTerm.Builder.Command[] The build commands.
---@field matcher BuildTerm.GroupMatcher The group matcher to use.
---@field terminal BuildTerm.Terminal The terminal to use.
---@field private __index any
local Builder = {}
Builder.__index = Builder

---Creates a build command trigger function.
local function to_trigger(config)
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

---Turns a single value into a list.
local function to_list(config)
	if type(config) == "string" then
		return { config }
	elseif type(config) == "table" then
		return config
	else
		return nil
	end
end

---Creates a new builder.
---@param matcher BuildTerm.GroupMatcher The group matcher to use.
---@param terminal BuildTerm.Terminal The terminal to use.
---@param config BuildTerm.Builder.Config? The builder config to use.
---@return BuildTerm.Builder
function M.new(matcher, terminal, config)
	local commands = {}

	for _, build_config in ipairs(config or {}) do
		local trigger = to_trigger(build_config.trigger)
		local command = to_command(build_config.command)
		local select = to_list(build_config.select)

		if not trigger or not command then
			error("Invalid build configuration " .. vim.inspect(build_config))
		end

		table.insert(commands, {
			trigger = trigger,
			command = command,
			select = select,
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
		matcher = matcher,
		commands = commands,
		terminal = terminal,
	}

	setmetatable(builder, Builder)
	return builder
end

---Runs the first build command that is triggered.
---Arguments are passed through to the build function.
function Builder:build(...)
	for _, builder in ipairs(self.commands) do
		if builder.trigger() then
			-- Reset the terminal if requested.
			if builder.reset then
				self.terminal:reset()
			elseif builder.clear then
				self.terminal:clear_matches()
			end

			-- Change the selected match groups.
			if builder.select then
				self.matcher:select(unpack(builder.select))
			end

			-- Issue the build commands.
			self.terminal:send(builder.command(...))
			return
		end
	end

	vim.notify("No matching builder was found.", vim.log.levels.WARN)
end

return M
