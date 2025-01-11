local M = {}

---@class BuildTerm.View.Config
---@field open fun(BuildTerm.Match): boolean Function used to open the file for a match.
---@field goto fun(BuildTerm.Match) Navigates to the match cursor position.
---@field find_view fun(): integer? Function to find a new view window.

---@class BuildTerm.View
---@field window integer The ID of the view window or -1.
---@field config BuildTerm.View.Config The view config.
---@field private __index any
local View = {}
View.__index = View

---Creates a new view.
function M.new(config)
	local def_config = {
		open = function(match)
			local file = match.data.file

			if not file then
				return false
			end

			if vim.fn.filereadable(file) == 1 then
				vim.cmd("silent edit " .. file)
				return true
			else
				vim.notify("File not found: " .. file, vim.log.levels.ERROR)
				return false
			end
		end,
		goto = function(match)
			local lnum = tonumber(match.data.lnum)
			local col = tonumber(match.data.col) or 1

			if lnum then
				vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
			end
		end,
		find_view = function()
			local best_win = nil
			local best_size = 0

			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local win_config = vim.api.nvim_win_get_config(win)

				if win_config then
					local size = win_config.width * win_config.height

					if size > best_size then
						best_win = win
						best_size = size
					end
				end
			end

			return best_win
		end
	}

	config = vim.tbl_extend("force", def_config, config or {})

	local view = {
		window = -1,
		config = config,
	}

	setmetatable(view, View)
	return view
end

---Focuses on the current view window.
function View:focus()
	if vim.api.nvim_win_is_valid(self.window) then
		vim.api.nvim_set_current_win(self.window)
	end
end

---Assigns the view window.
function View:set_window(id)
	self.window = id
end

---Navigates to the given match.
---@param match BuildTerm.Match? The match to navigate to.
---@param config BuildTerm.View.Config? View config overrides.
function View:goto_match(match, config)
	config = vim.tbl_extend("force", self.config, config or {})

	if not vim.api.nvim_win_is_valid(self.window) then
		local window = config.find_view()

		if vim.api.nvim_win_is_valid(window) then
			self.window = window
		else
			vim.notify("No view window available.", vim.log.levels.WARN)
			return
		end
	end

	if match then
		vim.api.nvim_set_current_win(self.window)

		if config.open(match) then
			config.goto(match)
		end
	end
end

return M
