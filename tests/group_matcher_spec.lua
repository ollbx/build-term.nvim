---@diagnostic disable: need-check-nil, invisible
local function new_matcher()
	local GroupMatcher = require("build-term.group_matcher")

	return GroupMatcher.new({
		default = {
			{ [=[\(.\)\(o[ou]\)]=], "a", "b" },
		},
		ext = {
			{ function(line) return line:sub(1, 2) == "ba" end },
			{ [=[\(.\)\(o[ou]\)\(bar\)]=], "a", "b", "c", priority = 2 },
			{ { "qux" }, { "fou" } },
		}
	})
end

describe("collect.match", function()
	local lines = {
		"wox",
		"foo",
		"foobar",
		"bar",
		"qux",
		"fou",
	}

	it("should match the default group", function()
		local matcher = new_matcher()
		assert.are.same({ "default" }, matcher:get_selected())
		assert.are.same(1, matcher:get_context())

		local result = matcher:scan(lines)
		for _, match in pairs(result) do match.matcher = nil end

		assert.are.same(
			{
				[2] = { data = { a = "f", b = "oo" }, length = 1, type = "hint" },
				[3] = { data = { a = "f", b = "oo" }, length = 1, type = "hint" },
				[6] = { data = { a = "f", b = "ou" }, length = 1, type = "hint" },
			},
			result
		)
	end)

	it("should match a non-default group", function()
		local matcher = new_matcher()
		matcher:select("ext")
		assert.are.same({ "ext" }, matcher:get_selected())
		assert.are.same(2, matcher:get_context())

		local result = matcher:scan(lines)
		for _, match in pairs(result) do match.matcher = nil end

		assert.are.same(
			{
				[3] = { data = { a = "f", b = "oo", c = "bar" }, length = 1, type = "hint" },
				[4] = { data = {}, length = 1, type = "hint" },
				[5] = { data = {}, length = 2, type = "hint" },
			},
			result
		)
	end)

	it("should match a multiple groups", function()
		local matcher = new_matcher()
		matcher:select("default", "ext")
		assert.are.same({ "default", "ext" }, matcher:get_selected())
		assert.are.same(2, matcher:get_context())

		local result = matcher:scan(lines)
		for _, match in pairs(result) do match.matcher = nil end

		assert.are.same(
			{
				[2] = { data = { a = "f", b = "oo" }, length = 1, type = "hint" },
				-- Note: priority 2 wins here.
				[3] = { data = { a = "f", b = "oo", c = "bar" }, length = 1, type = "hint" },
				[4] = { data = {}, length = 1, type = "hint" },
				[5] = { data = {}, length = 2, type = "hint" },
				[6] = { data = { a = "f", b = "ou" }, length = 1, type = "hint" },
			},
			result
		)
	end)
end)
