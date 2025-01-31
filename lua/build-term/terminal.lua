--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@alias BuildTerm.Terminal.WindowConfig vim.api.keyset.win_config|(fun(): vim.api.keyset.win_config)|nil
---@alias BuildTerm.Terminal.ShellFun fun(): string?

---@class BuildTerm.Terminal.Config: BuildTerm.Terminal.ShowConfig
---@field shell (BuildTerm.Terminal.ShellFun|string)? Specifies the shell command to execute. `nil` for default.

---@class BuildTerm.Terminal.ShowConfig
---@field focus boolean? `true` to move the cursor into the terminal on open.
---@field window BuildTerm.Terminal.WindowConfig The window configuration.
---@field init_buffer fun(buffer: integer)? Terminal buffer initialization hook function.
---@field init_window fun(window: integer)? Terminal window initialization hook function.
---@field on_focus fun()? Terminal window focus hook function.

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local M = {}

---@class BuildTerm.Terminal
---@field _buffer integer The terminal buffer (or -1 if uninitialized).
---@field _window integer The terminal window (or -1 if hidden).
---@field _config BuildTerm.Terminal.Config The terminal configuration.
---@field private __index any
local Terminal = {}
Terminal.__index = Terminal

---Creates a new terminal.
---@param config BuildTerm.Terminal.Config? The terminal config.
---@return BuildTerm.Terminal
function M.new(config)
	local def_config = {
		shell = nil,
		-- Default window is 25% on the bottom.
		window = function()
			return {
				split = "below",
				height = math.floor(vim.o.lines / 4),
			}
		end,
		-- Default init function sets up keymaps.
		init_buffer = function(buffer)
			-- Attach the match list to the buffer.
			local ok, MatchList = pcall(require, "match-list")

			if ok then
				MatchList.attach(buffer)
			end
		end,
		-- Default init function disables line numbers.
		init_window = function()
			vim.opt_local.nu = false
			vim.opt_local.relativenumber = false
		end,
		-- Default focus function enters insert mode.
		on_focus = function()
			vim.cmd.startinsert()
		end,
	}

	local terminal = {
		_buffer = -1,
		_window = -1,
		_config = vim.tbl_extend("force", def_config, config or {}),
	}

	setmetatable(terminal, Terminal)
	return terminal
end

---Opens the terminal split.
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function Terminal:show(config)
	config = vim.tbl_extend("force", self._config, config or {})

	-- Create a buffer if we have none.
	if not vim.api.nvim_buf_is_valid(self._buffer) then
		self._buffer = vim.api.nvim_create_buf(false, true)
	end

	-- Create the window if it is invalid.
	if not vim.api.nvim_win_is_valid(self._window) then
		local win_config = config.window

		if type(win_config) == "function" then
			win_config = win_config()
		end

		-- Create the window and switch to it.
		local prev_win = vim.api.nvim_get_current_win()
		win_config.win = -1
		self._window = vim.api.nvim_open_win(self._buffer, true, win_config)

		-- Initialize the window.
		config.init_window(self._window)

		-- If the buffer is not a terminal yet, enter terminal mode.
		if vim.bo[self._buffer].buftype ~= "terminal" then
			local shell = config.shell

			if type(shell) == "function" then
				shell = config.shell()
			end

			vim.cmd.terminal(shell)

			config.init_buffer(self._buffer)
		end

		if config.focus then
			config.on_focus()
		else
			vim.api.nvim_set_current_win(prev_win)
		end
	elseif config.focus then
		vim.api.nvim_set_current_win(self._window)
		config.on_focus()
	end
end

---Closes the terminal split.
function Terminal:close()
	if vim.api.nvim_win_is_valid(self._window) then
		vim.api.nvim_win_hide(self._window)
		self._window = -1
	end
end

---Resets the terminal. This will restart the shell process.
function Terminal:reset()
	local open = self:is_open()
	local focus = self:is_focused()

	self:close()

	if vim.api.nvim_buf_is_valid(self._buffer) then
		vim.api.nvim_buf_delete(self._buffer, { force = true })
		self._buffer = -1
	end

	if open then
		self:show({ focus = focus })
	end
end

---@return `true` if the terminal split is currently open.
function Terminal:is_open()
	return vim.api.nvim_win_is_valid(self._window)
end

---@return `true` if the terminal split is currently open and focused.
function Terminal:is_focused()
	return vim.api.nvim_win_is_valid(self._window) and vim.api.nvim_get_current_win() == self._window
end

---Toggles between closed and opened terminal split.
---@param config BuildTerm.Terminal.ShowConfig? Configuration overrides.
function Terminal:toggle(config)
	if not self:is_open() then
		self:show(config)
	else
		self:close()
	end
end

---Runs the specified command in the terminal.
---@param command string[]|string The commands to run.
---@param config BuildTerm.Terminal.Config? Configuration overrides.
function Terminal:send(command, config)
	self:show(config)

	if vim.api.nvim_buf_is_valid(self._buffer) then
		local channel = vim.bo[self._buffer].channel
		local newline = "\n"

		if vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1 then
			newline = "\r\n"
		end

		if type(command) == "table" then
			for _, line in ipairs(command) do
				vim.fn.chansend(channel, line .. newline)
			end
		else
			vim.fn.chansend(channel, command .. newline)
		end

		-- self.ve to the end of the buffer (so that it auto-scrolls).
		if vim.api.nvim_win_is_valid(self._window) then
			local prev_win = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(self._window)
			vim.cmd("norm G")
			vim.api.nvim_set_current_win(prev_win)
		end
	end
end

---Returns the current window ID.
function Terminal:get_window()
	return self._window
end

---Returns the current buffer ID.
function Terminal:get_buffer()
	return self._buffer
end

return M
