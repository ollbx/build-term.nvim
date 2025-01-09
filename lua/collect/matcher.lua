--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@class Collect.Matcher.Match
---@field matcher Collect.Matcher? The matcher that produced the result.
---@field offset integer The match offset.
---@field length integer The length of the match.
---@field mark integer? The extmark ID in the terminal buffer.
---@field data { string: string } The match data.

---@alias Collect.Matcher.LineMatcher fun(line: string): { string: string }|boolean|nil
---@alias Collect.Matcher.LineConfig string|string[]|Collect.Matcher.LineMatcher

---@class Collect.Matcher.Config
---@field type string? The type of the match.
---@field group string? The group for the matcher.
---@field priority integer? The priority for the matcher.
---@field mark_config vim.api.keyset.set_extmark? Extmark config override.
---@field match Collect.Matcher.LineConfig? Config for matching a single line.
---@field lines Collect.Matcher.LineConfig[]? Config for matching a multiple lines.

--------------------------------------------------------------------------------
-- Private functions
--------------------------------------------------------------------------------

---Creates a match function for matching a single line.
---@param config Collect.Matcher.LineConfig The match configuration.
---@return Collect.Matcher.LineMatcher? A function for matching a single line.
local function to_line_matcher(config)
	if type(config) == "string" then
		return function(line)
			local match = vim.fn.matchlist(line, config)

			-- If we have a capture group, only return data from that as the message.
			if match[2] ~= nil and match[2] ~= "" then
				return { message = match[2] }
			end

			-- Otherwise return an empty table.
			if match[1] then
				return true
			end

			return nil
		end
	elseif type(config) == "table" then
		return function(line)
			local match = vim.fn.matchlist(line, config[1])
			local result = {}

			if match[1] then
				for i = 2, #config do
					result[config[i]] = match[i]
				end

				return result
			end

			return nil
		end
	elseif type(config) == "function" then
		return config
	else
		return nil
	end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local M = {}

---@class Collect.Matcher
---@field type string The type of the match.
---@field group string The group that the matcher belongs to.
---@field priority integer The priority for the matcher.
---@field mark_config vim.api.keyset.set_extmark? Extmark config override.
---@field matchers Collect.Matcher.LineMatcher[] The matchers for the individual lines.
---@field private __index any
local Matcher = {}
Matcher.__index = Matcher

---Creates a matcher for potentially matching multiple lines.
---@param config Collect.Matcher.Config The match configuration.
---@return Collect.Matcher The matcher object.
function M.new(config)
	if config.lines and config.match then
		error("Match config contains lines and also match option.")
	end

	if config.match then
		config.lines = { config.match }
	end

	if not config.lines then
		error("Match config without lines or match option.")
	end

	local matchers = {}

	for _, line_config in ipairs(config.lines) do
		local matcher = to_line_matcher(line_config)

		if matcher then
			table.insert(matchers, matcher)
		else
			error("Invalid match config: " .. vim.inspect(line_config))
		end
	end

	local matcher = {
		matchers = matchers,
		group = config.group or "default",
		priority = config.priority or 0,
		mark_config = config.mark_config,
		type = config.type or "hint",
	}

	setmetatable(matcher, Matcher)
	return matcher
end

---@return integer The number of lines that are required for matching.
function Matcher:get_context()
	return #self.matchers
end

---Tries to match the lines at the given offset.
---@param lines string[] The lines to match against.
---@param offset integer The offset to match at.
---@return Collect.Matcher.Match? The matched data or `nil`.
function Matcher:match(lines, offset)
	local result = {}

	for i, matcher in ipairs(self.matchers) do
		local line = lines[offset + i - 1]

		if not line then
			return nil
		end

		local line_result = matcher(line)

		if line_result then
			if type(line_result) == "table" then
				result = vim.tbl_extend("force", result, line_result)
			end
		else
			return nil
		end
	end

	return {
		offset = offset,
		length = #self.matchers,
		data = result,
	}
end

---Finds all matches in the given array of lines.
---@param lines string[] The lines to match against.
---@return Collect.Matcher.Match[] A list of matches (in order).
function Matcher:scan(lines)
	local matches = {}

	for i = 1, #lines do
		local match = self:match(lines, i)

		if match then
			table.insert(matches, match)
		end
	end

	return matches
end

return M
