--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local M = {}
local Matcher = require("collect.matcher")

---@class Collect.GroupMatcher
---@field groups { string: Collect.Matcher.Config } The group matcher configurations.
---@field enabled { string: boolean } The enabled groups.
---@field private __index any
local GroupMatcher = {}
GroupMatcher.__index = GroupMatcher

---Creates a matcher for a groups of matchers.
---@param config { string: Collect.Matcher.Config[] } A map of matcher configurations.
---@return Collect.GroupMatcher The matcher object.
function M.new(config)
	local groups = {}

	-- Create matchers for all the groups.
	for name, group_config in pairs(config) do
		local group = {}

		for _, matcher_config in ipairs(group_config) do
			table.insert(group, Matcher.new(matcher_config))
		end

		groups[name] = group
	end

	local matcher = {
		groups = groups,
		enabled = { default = true },
	}

	setmetatable(matcher, GroupMatcher)
	return matcher
end

---@return string[] # The currently selected match groups in order.
function GroupMatcher:get_selected()
	local groups = {}

	for group, _ in pairs(self.enabled) do
		table.insert(groups, group)
	end

	table.sort(groups)
	return groups
end

---Sets the enabled groups.
function GroupMatcher:select(...)
	local groups = { ... }
	self.enabled = {}

	if #groups == 0 then
		self.enabled["default"] = true
	end

	for _, group in ipairs(groups) do
		self.enabled[group] = true
	end
end

---@return integer The context required for matching the selected groups.
function GroupMatcher:get_context()
	local context = 1

	for group, _ in pairs(self.enabled) do
		local matchers = self.groups[group] or {}

		for _, matcher in ipairs(matchers) do
			if matcher:get_context() > context then
				context = matcher:get_context()
			end
		end
	end

	return context
end

---Scans the given lines for matches using all matchers of the current group.
---@param lines string[] The lines to scan.
---@return Collect.Matcher.Match[] # A list of matches.
function GroupMatcher:scan(lines)
	local matches = {}

	for group, _ in pairs(self.enabled) do
		local matchers = self.groups[group] or {}

		for _, matcher in ipairs(matchers) do
			for _, match in ipairs(matcher:scan(lines)) do
				local offset = match.offset

				-- For each offset only keep the match with the highest priority.
				if matches[offset] == nil or matcher.priority >= matches[offset].matcher.priority then
					match.matcher = matcher
					matches[offset] = match
				end
			end
		end
	end

	-- Make a list.
	local list = {}

	for _, matcher in pairs(matches) do
		table.insert(list, matcher)
	end

	return list
end

return M
