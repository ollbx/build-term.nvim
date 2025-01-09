--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local M = {}

---@alias BuildTerm.GroupMatcher.Config { string: BuildTerm.Matcher.Config[] }

---@class BuildTerm.GroupMatcher
---@field groups { string: BuildTerm.Matcher.Config } The group matcher configurations.
---@field enabled { string: boolean } The enabled groups.
---@field private __index any
local GroupMatcher = {}
GroupMatcher.__index = GroupMatcher

---Creates a matcher for a groups of matchers.
---@param config BuildTerm.GroupMatcher.Config? A map of matcher configurations.
---@return BuildTerm.GroupMatcher The matcher object.
function M.new(config)
	local Matcher = require("build-term.matcher")
	local groups = {}

	-- Create matchers for all the groups.
	for name, group_config in pairs(config or {}) do
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

---Returns all available match groups in order.
function GroupMatcher:get_groups()
	local groups = {}

	for group, _ in pairs(self.groups) do
		table.insert(groups, group)
	end

	table.sort(groups)
	return groups
end

---Returns the selected match groups in order.
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

---@return integer # The context required for matching the selected groups.
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
---@return BuildTerm.Match[] # A list of matches.
function GroupMatcher:scan(lines)
	local matches = {}
	local index = {}

	for i = 1, #lines do
		for group, _ in pairs(self.enabled) do
			local matchers = self.groups[group] or {}

			for _, matcher in ipairs(matchers) do
				local match = matcher:match(lines, i)

				if match then
					match.matcher = matcher
					match.offset = i

					if index[i] == nil then
						-- Append the match at the end.
						index[i] = match
						table.insert(matches, match)
					elseif matcher.priority >= index[i].matcher.priority then
						-- Replace the last match, if the new one has higher priority.
						index[i] = match
						matches[#matches] = match
					end
				end
			end
		end
	end

	return matches
end

return M
