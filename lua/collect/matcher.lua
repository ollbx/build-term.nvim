local M = {}

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@alias Collect.MatchResult { string: string }|boolean|nil
---@alias Collect.LineMatcher fun(line: string): Collect.MatchResult
---@alias Collect.LineMatcherConfig string|string[]|Collect.LineMatcher

---@class Collect.MatcherConfig
---@field match Collect.LineMatcherConfig? Config for matching a single line.
---@field lines Collect.LineMatcherConfig[]? Config for matching a multiple lines.

--------------------------------------------------------------------------------
-- Private functions
--------------------------------------------------------------------------------

---Creates a match function for matching a single line.
---@param config Collect.LineMatcherConfig The match configuration.
---@return Collect.LineMatcher? A function for matching a single line.
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
				for i = 2, #match do
					result[match[i]] = match[i]
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

---@class Collect.Matcher
---@field matchers Collect.LineMatcher[] The matchers for the individual lines.
---@field private __index any
local Matcher = {}
Matcher.__index = Matcher

---Creates a matcher for potentially matching multiple lines.
---@param config Collect.MatcherConfig The match configuration.
---@return Collect.Matcher? The matcher object.
function M.new(config)
	if config.lines and config.match then
		vim.notify("Match config contains lines and match option.", vim.log.levels.WARN)
		return nil
	end

	if config.match then
		config.lines = { config.match }
	end

	local matchers = {}

	for _, line_config in ipairs(config.lines) do
		local matcher = to_line_matcher(line_config)

		if matcher then
			table.insert(matchers, matcher)
		else
			vim.notify("Invalid match config: " .. vim.inspect(line_config), vim.log.levels.WARN)
			return nil
		end
	end

	local matcher = {
		matchers = matchers,
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
---@return Collect.MatchResult The matched data or `nil`.
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

	return result
end

---Finds all matches in the given array of lines.
---@param lines string[] The lines to match against.
---@return { integer: Collect.MatchResult } A map of matches (by offset).
function Matcher:scan(lines)
	local matches = {}

	for i = 1, #lines do
		local match = self:match(lines, i)

		if match then
			matches[i] = match
		end
	end

	return matches
end

return M
