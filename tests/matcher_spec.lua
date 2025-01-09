---@diagnostic disable: need-check-nil
local Matcher = require("collect.matcher")

describe("collect.matcher", function()
	local lines = {
		"woo",
		"foo",
		"bar",
		"qux",
		"fou",
		"bar"
	}

	it("should match a regex", function()
		local matcher = Matcher.new({ match = ".o[ou]" })

		assert.is_truthy(matcher)
		assert.are.same(1, matcher:get_context())
		assert.are.same({ data = {}, offset = 1, length = 1 }, matcher:match(lines, 1))
		assert.are.same({ data = {}, offset = 2, length = 1 }, matcher:match(lines, 2))
		assert.are.same(nil, matcher:match(lines, 3))

		assert.are.same(
			{
				{ data = {}, offset = 1, length = 1 },
				{ data = {}, offset = 2, length = 1 },
				{ data = {}, offset = 5, length = 1 },
			},
			matcher:scan(lines)
		)
	end)

	it("should match a regex with an unnamed group", function()
		local matcher = Matcher.new({ match = [=[\(.\)o[ou]]=] })

		assert.is_truthy(matcher)
		assert.are.same(1, matcher:get_context())
		assert.are.same({ data = { message = "w" }, offset = 1, length = 1 }, matcher:match(lines, 1))
		assert.are.same({ data = { message = "f" }, offset = 2, length = 1 }, matcher:match(lines, 2))
		assert.are.same(nil, matcher:match(lines, 3))

		assert.are.same(
			{
				{ data = { message = "w" }, offset = 1, length = 1 },
				{ data = { message = "f" }, offset = 2, length = 1 },
				{ data = { message = "f" }, offset = 5, length = 1 },
			},
			matcher:scan(lines)
		)
	end)

	it("should match a regex with named groups", function()
		local matcher = Matcher.new({
			match = { [=[\(.\)\(o[ou]\)]=], "head", "tail" }
		})

		assert.is_truthy(matcher)
		assert.are.same(1, matcher:get_context())
		assert.are.same({ data = { head = "w", tail = "oo" }, offset = 1, length = 1 }, matcher:match(lines, 1))
		assert.are.same({ data = { head = "f", tail = "oo" }, offset = 2, length = 1 }, matcher:match(lines, 2))
		assert.are.same(nil, matcher:match(lines, 3))

		assert.are.same(
			{
				{ data = { head = "w", tail = "oo" }, offset = 1, length = 1 },
				{ data = { head = "f", tail = "oo" }, offset = 2, length = 1 },
				{ data = { head = "f", tail = "ou" }, offset = 5, length = 1 },
			},
			matcher:scan(lines)
		)
	end)

	it("should match a function returning a bool", function()
		local matcher = Matcher.new({
			match = function(line)
				return line:sub(1, 2) == "fo"
			end
		})

		assert.is_truthy(matcher)
		assert.are.same(1, matcher:get_context())
		assert.are.same(nil, matcher:match(lines, 1))
		assert.are.same({ data = {}, offset = 2, length = 1 }, matcher:match(lines, 2))
		assert.are.same(nil, matcher:match(lines, 3))

		assert.are.same(
			{
				{ data = {}, offset = 2, length = 1 },
				{ data = {}, offset = 5, length = 1 },
			},
			matcher:scan(lines)
		)
	end)

	it("should match a function returning a table", function()
		local matcher = Matcher.new({
			match = function(line)
				if line:sub(1, 2) == "fo" then
					return { tail = line:sub(2) }
				end
			end
		})

		assert.is_truthy(matcher)
		assert.are.same(1, matcher:get_context())
		assert.are.same(nil, matcher:match(lines, 1))
		assert.are.same({ data = { tail = "oo" }, offset = 2, length = 1 }, matcher:match(lines, 2))
		assert.are.same(nil, matcher:match(lines, 3))

		assert.are.same(
			{
				{ data = { tail = "oo" }, offset = 2, length = 1 },
				{ data = { tail = "ou" }, offset = 5, length = 1 },
			},
			matcher:scan(lines)
		)
	end)

	it("should match multiple lines", function()
		local matcher = Matcher.new({
			lines = {
				{ [=[\(.\)\(o[ou]\)]=], "head", "tail" },
				function(line) if line == "bar" then return { next = line } end end,
			}
		})

		assert.is_truthy(matcher)
		assert.are.same(2, matcher:get_context())
		assert.are.same(nil, matcher:match(lines, 1))
		assert.are.same({ data = { head = "f", tail = "oo", next = "bar" }, offset = 2, length = 2 }, matcher:match(lines, 2))

		assert.are.same(
			{
				{ data = { head = "f", tail = "oo", next = "bar" }, offset = 2, length = 2 },
				{ data = { head = "f", tail = "ou", next = "bar" }, offset = 5, length = 2 },
			},
			matcher:scan(lines)
		)
	end)

	it("should fail on invalid type", function()
		assert.has_error(function()
			---@diagnostic disable-next-line: assign-type-mismatch
			Matcher.new({ match = 5 })
		end)
	end)

	it("should fail without match config", function()
		assert.has_error(function()
			Matcher.new({})
		end)
	end)

	it("should fail with ambiguous match config", function()
		assert.has_error(function()
			Matcher.new({
				lines = { "" },
				match = "",
			})
		end)
	end)
end)
