---@alias Collect.Terminal.WindowConfig vim.api.keyset.win_config|(fun(): vim.api.keyset.win_config)|nil

---@class Collect.Terminal.Config
---@field focus boolean? `true` to move the cursor into the terminal on open.
---@field shell string? Specifies the shell command to execute. `nil` for default.
---@field window Collect.Terminal.WindowConfig The window configuration.
---@field on_init fun()? Terminal window initialization hook function.
---@field on_focus fun()? Terminal window focus hook function.

-- TODO:
-- * Multiple match configurations.

---@class Collect.Terminal
local M = {
	namespace = vim.api.nvim_create_namespace("collect.nvim"),

	---Buffer ID of the current terminal buffer.
	buffer = -1,

	---Window ID of the current window (-1 if closed).
	window = -1,

	---The current matches.
	matches = {},

	---Default configuration for the terminal.
	---@type Collect.Terminal.Config
	config = {
		focus = false,
		shell = nil,
		-- Default window is 25% on the bottom.
		window = function()
			return {
				split = "below",
				height = math.floor(vim.o.lines / 4),
			}
		end,
		-- Default init function disables line numbers.
		on_init = function()
			vim.opt_local.nu = false
			vim.opt_local.relativenumber = false
		end,
		-- Default focus function enters insert mode.
		on_focus = function()
			vim.cmd.startinsert()
		end
	},
}

local GroupMatcher = require("collect.group_matcher")

--- Handles new output on the terminal buffer.
local function handle_output(_, _, _, first, last)
	-- TODO:
	-- * Scan output.
	-- * Set extmark and remember the ID.
	-- * When navigating, use the extmark to retrieve the position.
	--   * This should be immune to scrolling.

	-- Extend the area by the context required.
	local context = GroupMatcher.get_context()
	first = math.max(0, first - context)
	last = last + context

	-- Retrieve the changed lines and match on them.
	local lines = vim.api.nvim_buf_get_lines(M.buffer, first, last, false)
	local matches = GroupMatcher.scan(lines)

	for _, match in ipairs(matches) do
		-- 0-based index.
		local offset = first + match.offset - 1

		-- Search for existing extmarks that overlap our line.
		local found = vim.api.nvim_buf_get_extmarks(
			M.buffer,
			M.namespace,
			{ offset, 0 },
			{ offset, 0 },
			{ overlap = true })

		if #found == 0 then
			local config = {
				end_row = offset + match.length - 1,
				hl_eol = true,
				sign_text = "H",
				sign_hl_group = "DiagnosticSignHint",
				hl_mode = "combine",
			}

			if match.matcher.type == "error" then
				config.sign_text = "E"
				config.sign_hl_group = "DiagnosticSignError"
			elseif match.matcher.type == "warn" then
				config.sign_text = "W"
				config.sign_hl_group = "DiagnosticSignWarn"
			elseif match.matcher.type == "info" then
				config.sign_text = "I"
				config.sign_hl_group = "DiagnosticSignInfo"
			end

			config.line_hl_group = config.sign_hl_group

			if match.matcher.mark_config then
				config = vim.tbl_extend("force", config, match.matcher.mark_config)
			end

			match.mark = vim.api.nvim_buf_set_extmark(
				M.buffer,
				M.namespace,
				offset,
				0,
				config)

			M.matches[offset] = match
		end
	end
end

--- Sets up the terminal component.
--- @private
function M.setup(config)
	M.config = vim.tbl_extend("force", M.config, config or {})
end

---Opens the terminal split.
---@param config Collect.Terminal.Config? Configuration overrides.
function M.open(config)
	config = vim.tbl_extend("force", M.config, config or {})

	-- Create a buffer if we have none.
	if not vim.api.nvim_buf_is_valid(M.buffer) then
		M.buffer = vim.api.nvim_create_buf(false, true)
	end

	-- Create the window if it is invalid.
	if not vim.api.nvim_win_is_valid(M.window) then
		local win_config = config.window

		if type(win_config) == "function" then
			win_config = win_config()
		end

		-- Create the window and switch to it.
		local prev_win = vim.api.nvim_get_current_win()
		win_config.win = -1
		M.window = vim.api.nvim_open_win(M.buffer, true, win_config)

		-- Initialize the window.
		config.on_init()

		-- If the buffer is not a terminal yet, enter terminal mode.
		if vim.bo[M.buffer].buftype ~= "terminal" then
			vim.cmd.terminal(config.shell)

			vim.api.nvim_buf_attach(M.buffer, false, {
				on_lines = handle_output,
			})
		end

		if config.focus then
			config.on_focus()
		else
			vim.api.nvim_set_current_win(prev_win)
		end
	elseif config.focus then
		vim.api.nvim_set_current_win(M.window)
		config.on_focus()
	end
end

---Closes the terminal split.
function M.close()
	if vim.api.nvim_win_is_valid(M.window) then
		vim.api.nvim_win_hide(M.window)
		M.window = -1
	end
end

---Resets the terminal. This will restart the shell process.
function M.reset()
	local open = M.is_open()
	local focus = M.is_focused()

	M.close()

	if vim.api.nvim_buf_is_valid(M.buffer) then
		vim.api.nvim_buf_delete(M.buffer, { force = true })
		M.buffer = -1
	end

	if open then
		M.open({ focus = focus })
	end
end

---@return `true` if the terminal split is currently open.
function M.is_open()
	return vim.api.nvim_win_is_valid(M.window)
end

---@return `true` if the terminal split is currently closed.
function M.is_closed()
	return not M.is_open()
end

---@return `true` if the terminal split is currently open and focused.
function M.is_focused()
	return vim.api.nvim_win_is_valid(M.window) and vim.api.nvim_get_current_win() == M.window
end

---Toggles between closed and opened terminal split.
---@param config Collect.Terminal.Config? Configuration overrides.
function M.toggle(config)
	if M.is_closed() then
		M.open(config)
	else
		M.close()
	end
end

---Runs the specified command in the terminal.
---@param cmd string The command to run.
function M.send(cmd)
	if vim.api.nvim_buf_is_valid(M.buffer) then
		local channel = vim.bo[M.buffer].channel
		vim.fn.chansend(channel, cmd .. "\r\n")

		-- Move to the end of the buffer (so that it auto-scrolls).
		if vim.api.nvim_win_is_valid(M.window) then
			local prev_win = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(M.window)
			vim.cmd("norm G")
			vim.api.nvim_set_current_win(prev_win)
		end
	end
end

return M
