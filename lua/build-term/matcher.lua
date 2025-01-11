--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@alias BuildTerm.Matcher.LineMatcher fun(line: string): { string: string }|boolean|nil
---@alias BuildTerm.Matcher.LineConfig string|string[]|BuildTerm.Matcher.LineMatcher

---@class BuildTerm.Matcher.Config
---@field type string? The type of the match.
---@field priority integer? The priority for the matcher.
---@field match BuildTerm.Matcher.LineConfig? Config for matching a single line.
---@field lines BuildTerm.Matcher.LineConfig[]? Config for matching a multiple lines.

--------------------------------------------------------------------------------
-- Private functions
--------------------------------------------------------------------------------

---Creates a match function for matching a single line.
---@param config BuildTerm.Matcher.LineConfig The match configuration.
---@return BuildTerm.Matcher.LineMatcher? A function for matching a single line.
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

---@class BuildTerm.Matcher
---@field type? string The type of the match.
---@field priority integer The priority for the matcher.
---@field matchers BuildTerm.Matcher.LineMatcher[] The matchers for the individual lines.
---@field private __index any
local Matcher = {}
Matcher.__index = Matcher

---Creates a matcher for potentially matching multiple lines.
---@param config BuildTerm.Matcher.Config The match configuration.
---@return BuildTerm.Matcher The matcher object.
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
		priority = config.priority or 0,
		type = config.type,
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
---@return BuildTerm.Match? The matched data or `nil`.
function Matcher:match(lines, offset)
	local data = {}

	for i, matcher in ipairs(self.matchers) do
		local line = lines[offset + i - 1]

		if not line then
			return nil
		end

		local line_result = matcher(line)

		if line_result then
			if type(line_result) == "table" then
				data = vim.tbl_extend("force", data, line_result)
			end
		else
			return nil
		end
	end

	local type = self.type

	if not type then
		if data.type then
			type = data.type
		else
			type = "hint"
		end
	end

	return {
		length = #self.matchers,
		data = data,
		type = type,
	}
end

return M
