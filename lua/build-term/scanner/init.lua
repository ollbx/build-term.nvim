-- Scanners will scan a buffer range or a single line for matches of a pattern.
-- They can match single or multiple lines.

---@class BuildTerm.Scanner
---@field scan fun(self: BuildTerm.Scanner, buffer: integer, first: integer?, last: integer?): [BuildTerm.Match]
---@field get_lines fun(): integer

---@class BuildTerm.Match
---@field buffer integer The buffer that the match was on.
---@field lines integer The number of lines matched.
---@field lnum integer The line number of the match.
---@field data BuildTerm.MatchData The captured data of the match.

---@alias BuildTerm.PostProcFun fun(data: BuildTerm.MatchData): BuildTerm.MatchData?

local M = {
	new_eval = require("build-term.scanner.eval").new,
	new_regex = require("build-term.scanner.regex").new,
	new_match = require("build-term.scanner.match").new,
	new_lpeg = require("build-term.scanner.lpeg").new,
	new_multi_line = require("build-term.scanner.multi-line").new,
}

---Parses a scanner configuration.
function M.parse(config)
	if type(config) == "function" then
		return M.new_eval(config)
	elseif type(config) == "string" then
		return M.new_eval(function(line)
			if line == config then
				return {}
			end
		end)
	elseif config["regex"] then
		local groups = (config["groups"] or config[1]) or {}
		return M.new_regex(config["regex"], groups, config["filter"])
	elseif config["match"] then
		local groups = (config["groups"] or config[1]) or {}
		return M.new_match(config["match"], groups, config["filter"])
	elseif config["lpeg"] then
		local groups = (config["groups"] or config[1]) or {}
		return M.new_lpeg(config["lpeg"], groups, config["filter"])
	elseif config["eval"] then
		return M.new_eval(config["eval"])
	elseif type(config[1]) == "string" then
		local groups = (config["groups"] or config[2]) or {}
		return M.new_regex(config[1], groups, config["filter"])
	elseif type(config[1]) == "function" then
		return M.new_eval(config[1])
	elseif type(config[1]) == "table" then
		local lines = {}

		for _, line in ipairs(config) do
			table.insert(lines, M.parse(line))
		end

		return M.new_multi_line(lines)
	else
		error("Invalid scanner config: " .. vim.inspect(config))
	end
end

---Parses a scanner group configuration.
function M.parse_groups(config)
	local groups = {}

	for group, scanner_configs in pairs(config) do
		local scanners = {}

		for _, scanne_config in ipairs(scanner_configs) do
			table.insert(scanners, M.parse(scanne_config))
		end

		groups[group] = scanners
	end

	return groups
end

return M
