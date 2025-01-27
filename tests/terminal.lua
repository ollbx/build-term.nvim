local function filter(matches)
	if not matches then
		return matches
	end

	local result = {}

	for offset, match in pairs(matches) do
		result[offset] = {
			data = match.data,
			length = match.length,
			type = match.type,
		}
	end

	return result
end

local function new_terminal()
	local Terminal = require("build-term.terminal")
	local GroupMatcher = require("build-term.group_matcher")

	local matcher = GroupMatcher.new({
		default = {
			{
				type = "error",
				{ [=[error: \(.*\)]=], "message" },
				{ [=[file: \(.*\)]=], "file" },
			}
		}
	})

	local terminal = Terminal.new(matcher, {})
	local buffer = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
		"Test buffer line 0",
		"Test buffer line 1",
		"error: test message",
		"file: test.txt",
		"Test buffer line 4",
		"Test buffer line 5",
	})

	terminal.buffer = buffer
	return terminal
end

describe("build-term.terminal", function()
	local expect = {
		data = { message = "test message", file = "test.txt" },
		length = 2,
		type = "error"
	}

	it("should match correctly", function()
		local terminal = new_terminal()
		terminal:rebuild_matches()

		-- We should have matched the expected item.
		assert.are.same({ [2] = expect }, filter(terminal:visit_range_as_map(0, -1)))

		-- Nothing should match in line 0-1.
		assert.are.same({}, filter(terminal:visit_range_as_map(0, 1)))

		-- 0-2 should contain the match, even though it goes up to line 3.
		assert.are.same({ [2] = expect }, filter(terminal:visit_range_as_map(0, 2)))

		-- 3-rest should't match anything.
		assert.are.same({}, filter(terminal:visit_range_as_map(3, -1)))
	end)

	it("should scan correctly", function()
		local terminal = new_terminal()

		-- We should have matched the expected item.
		assert.are.same({ [2] = expect }, filter(terminal:scan_range_as_map(0, -1)))

		-- Nothing should match in line 0-1.
		assert.are.same({}, filter(terminal:scan_range_as_map(0, 1)))

		-- 0-2 should contain the match, even though it goes up to line 3.
		assert.are.same({ [2] = expect }, filter(terminal:scan_range_as_map(0, 2)))

		-- 3-rest should't match anything.
		assert.are.same({}, filter(terminal:scan_range_as_map(3, -1)))
	end)

	local expect2 = {
		data = { message = "changed test message", file = "test.txt" },
		length = 2,
		type = "error"
	}

	local expect3 = {
		data = { message = "new test message", file = "test2.txt" },
		length = 2,
		type = "error"
	}

	it("should replace correctly", function()
		local terminal = new_terminal()
		terminal:rebuild_matches()

		-- Check the initial match.
		assert.are.same({ [2] = expect }, filter(terminal:visit_range_as_map(0, -1)))

		-- Change the text message, rescan and verify.
		vim.api.nvim_buf_set_lines(terminal.buffer, 2, 3, false, {
			"error: changed test message"
		})

		terminal:rescan_lines(2, 3)
		assert.are.same({ [2] = expect2 }, filter(terminal:visit_range_as_map(0, -1)))

		-- Invalidate the first match, rescan and verify.
		vim.api.nvim_buf_set_lines(terminal.buffer, 2, 3, false, {
			"this is a changed line"
		})

		terminal:rescan_lines(2, 3)
		assert.are.same({}, filter(terminal:visit_range_as_map(0, -1)))

		-- Create a new match, rescan and verify.
		vim.api.nvim_buf_set_lines(terminal.buffer, 4, 6, false, {
			"error: new test message",
			"file: test2.txt",
		})

		terminal:rescan_lines(4, 6)
		assert.are.same({ [4] = expect3 }, filter(terminal:visit_range_as_map(4, 6)))
	end)
end)
