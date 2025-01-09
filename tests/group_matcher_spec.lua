---@diagnostic disable: need-check-nil, invisible
local GroupMatcher = require("collect.group_matcher")

local function new_matcher()
	return GroupMatcher.new({
		default = {
			{ match = { [=[\(.\)\(o[ou]\)]=], "a", "b" } },
		},
		ext = {
			{ match = function(line) return line:sub(1, 2) == "ba" end },
			{ match = { [=[\(.\)\(o[ou]\)\(bar\)]=], "a", "b", "c" }, priority = 2 },
			{ lines = { "qux", "fou" } },
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
		for _, match in ipairs(result) do match.matcher = nil end
		table.sort(result, function(a, b) return a.offset < b.offset end)

		assert.are.same(
			{
				{ data = { a = "f", b = "oo" }, offset = 2, length = 1 },
				{ data = { a = "f", b = "oo" }, offset = 3, length = 1 },
				{ data = { a = "f", b = "ou" }, offset = 6, length = 1 },
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
		for _, match in ipairs(result) do match.matcher = nil end
		table.sort(result, function(a, b) return a.offset < b.offset end)

		assert.are.same(
			{
				{ data = { a = "f", b = "oo", c = "bar" }, offset = 3, length = 1 },
				{ data = {}, offset = 4, length = 1 },
				{ data = {}, offset = 5, length = 2 },
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
		for _, match in ipairs(result) do match.matcher = nil end
		table.sort(result, function(a, b) return a.offset < b.offset end)

		assert.are.same(
			{
				{ data = { a = "f", b = "oo" }, offset = 2, length = 1 },
				-- Note: priority 2 wins here.
				{ data = { a = "f", b = "oo", c = "bar" }, offset = 3, length = 1 },
				{ data = {}, offset = 4, length = 1 },
				{ data = {}, offset = 5, length = 2 },
				{ data = { a = "f", b = "ou" }, offset = 6, length = 1 },
			},
			result
		)
	end)
end)
