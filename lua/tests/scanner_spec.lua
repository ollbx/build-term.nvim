describe("build-term.scanner", function()
	local Scanner = require("build-term.scanner")
	local Util = require("build-term.util")

	local function filter(matches)
		return Util.simplify_matches(matches, true)
	end

	local lines = {
		"this is a test line",  -- 1
		"this is another line", -- 2
		"12 bottles of beer",   -- 3
		"no more microwaves",   -- 4
		"25 bottles of beer",   -- 5
		"reticulating splines", -- 6
	}

	it("should support regex", function()
		local buffer = Util.make_buffer(lines)
		local expr = [[^\(\d\+\) bottles of beer]]
		local scanner = Scanner.new_regex(expr, { "count", type = "info" })
		local matches = filter(scanner:scan(buffer))

		assert.are.same(1, scanner:get_lines())
		assert.are.same({
			{ lines = { "12 bottles of beer" }, lnum = 3, data = { count = "12", type = "info" } },
			{ lines = { "25 bottles of beer" }, lnum = 5, data = { count = "25", type = "info" } },
		}, matches)

		-- Try a filter function.
		scanner = Scanner.new_regex(expr, { "count" }, function(data)
			local count = tonumber(data.count)

			if count > 15 then
				return { count = count * 2, type = "info" }
			end
		end)

		matches = filter(scanner:scan(buffer))

		assert.are.same({
			{ lines = { "25 bottles of beer" }, lnum = 5, data = { count = 50, type = "info" } },
		}, matches)
	end)

	it("should support lua match", function()
		local buffer = Util.make_buffer(lines)
		local expr = [[^(%d+) bottles of beer]]
		local scanner = Scanner.new_match(expr, { "count", type = "info" })
		local matches = filter(scanner:scan(buffer))

		assert.are.same(1, scanner:get_lines())
		assert.are.same({
			{ lines = { "12 bottles of beer" }, lnum = 3, data = { count = "12", type = "info" } },
			{ lines = { "25 bottles of beer" }, lnum = 5, data = { count = "25", type = "info" } },
		}, matches)

		-- Try a filter function.
		scanner = Scanner.new_match(expr, { "count" }, function(data)
			local count = tonumber(data.count)

			if count > 15 then
				return { count = count * 2, type = "info" }
			end
		end)

		matches = filter(scanner:scan(buffer))

		assert.are.same({
			{ lines = { "25 bottles of beer" }, lnum = 5, data = { count = 50, type = "info" } },
		}, matches)
	end)

	it("should support lpeg", function()
		local lpeg = require("lpeg")
		local buffer = Util.make_buffer(lines)
		local expr = lpeg.C(lpeg.R("09")^1) * lpeg.P(" bottles of beer")
		local scanner = Scanner.new_lpeg(expr, { "count", type = "info" })
		local matches = filter(scanner:scan(buffer))

		assert.are.same(1, scanner:get_lines())
		assert.are.same({
			{ lines = { "12 bottles of beer" }, lnum = 3, data = { count = "12", type = "info" } },
			{ lines = { "25 bottles of beer" }, lnum = 5, data = { count = "25", type = "info" } },
		}, matches)

		-- Try a filter function.
		scanner = Scanner.new_lpeg(expr, { "count" }, function(data)
			local count = tonumber(data.count)

			if count > 15 then
				return { count = count * 2, type = "info" }
			end
		end)

		matches = filter(scanner:scan(buffer))

		assert.are.same({
			{ lines = { "25 bottles of beer" }, lnum = 5, data = { count = 50, type = "info" } },
		}, matches)
	end)

	it("should support multi-line", function()
		local buffer = Util.make_buffer(lines)

		local scanner = Scanner.new_multi_line {
			Scanner.new_regex([[^\(\d\+\) bottles of beer]], { "count" }),
			Scanner.new_match([[no (%w+) microwaves]], { "more", type = "info" }),
		}

		local expect = {
			lines = { "12 bottles of beer", "no more microwaves" },
			lnum = 3,
			data = { count = "12", more = "more", type = "info" },
		}

		assert.are.same(2, scanner:get_lines())

		local matches = filter(scanner:scan(buffer))
		assert.are.same({ expect }, matches)

		-- If the first line is in the range, the whole thing should match.
		matches = filter(scanner:scan(buffer, 1, 3))
		assert.are.same({ expect }, matches)

		-- If the first line is not in range, nothing should match.
		matches = filter(scanner:scan(buffer, 1, 2))
		assert.are.same({}, matches)
	end)
end)
