local M = {}
local Item = {}

M.namespace = vim.api.nvim_create_namespace("collect.nvim")

---@class Collect.Item
---@field key       string       The unique key that identifies the item.
---@field msg_bufnr integer      The (terminal) buffer that contains the message.
---@field msg_lnum  integer      The line number of the message.
---@field regex     string[]     The regex (one per line) that were matched.
---@field message   string|nil   The message associated with the item.
---@field path      string|nil   The path associated with the item.
---@field lnum      integer|nil  The line number associated with the item.
---@field col       integer|nil
---@field sign      string|nil   The sign text.
---@field show_message function
---@field show_source function

---@class Collect.MatchConfig
---@field regex string[][] Contains a regex for each matched line, followed by
---                        names for the matched groups.
---@field type string The type of the match.

---Matches items in the given buffer.
---@param bufnr   integer  The (terminal) buffer to scan.
---@param first   integer  The first line to scan.
---@param last    integer  The last line to scan.
---@param matches Collect.MatchConfig[] The match configuration.
---@return { [string]: Collect.Item } The matched items.
function M.match(bufnr, first, last, matches)
	-- Determine the amount of context needed for scanning.
	local context = 0;

	for _, match in ipairs(matches) do
		if #match.regex > context then
			context = #match.regex
		end
	end

	context = context - 1

	local first_ctx = math.max(0, first - context)
	local collect = {}

	-- Note the function will automatically clamp line indices.
	local lines = vim.api.nvim_buf_get_lines(
		bufnr,
		first_ctx,
		last + context,
		false)

	for i = 1, #lines do
		for j, match in ipairs(matches) do
			local lnum = first_ctx + i -- one-based index
			local key = bufnr .. "_" .. lnum .. "_" .. j

			if not collect[key] then
				local item = {
					key       = key,
					msg_bufnr = bufnr,
					msg_lnum  = lnum,
					regex     = match.regex,
					type      = match.type or "hint",
					message   = nil,
					path      = nil,
					lnum      = nil,
					col       = nil,
				}

				setmetatable(item, { __index = Item })

				if item:match(lines, i, true) then
					table.insert(collect, item)
				end
			end
		end
	end

	return collect
end

---Matches the item against the given line array and offset.
---@param  lines  string[] The lines to match against.
---@param  offset integer  The offset in the array to start at.
---@param  update boolean  `true` to extract data from the lines using regex.
---@return boolean `true` if the item could be matched successfully.
function Item:match(lines, offset, update)
	for i, regex in ipairs(self.regex) do
		local line = lines[offset + i - 1]

		if not line then
			return false
		end

		local result = vim.fn.matchlist(line, regex[1])

		if result[1] then
			if update then
				for j = 2, #regex do
					self[regex[j]] = result[j]
				end
			end
		else
			return false
		end
	end

	return true
end

---Confirms that item still matches the buffer contents.
---@return boolean `true` if the item matched successfully.
function Item:confirm()
	local lines = vim.api.nvim_buf_get_lines(
		self.msg_bufnr,
		self.msg_lnum,
		self.msg_lnum + #self.regex,
		false)

	return self:match(lines, 1, false)
end

---Navigates to the items message.
function Item:show_message()
	vim.api.nvim_set_current_buf(self.msg_bufnr)
	vim.api.nvim_win_set_cursor(0, { self.msg_lnum, 0 })

	vim.api.nvim_buf_clear_namespace(self.msg_bufnr, M.namespace, 0, -1)

	vim.api.nvim_buf_set_extmark(
		self.msg_bufnr,
		M.namespace,
		self.msg_lnum - 1,
		0,
		{ end_row = self.msg_lnum + #self.regex - 1, hl_eol = true, hl_group = "Visual" }
	)

	--vim.api.nvim_buf_set_extmark()
	--local nid = vim.api.nvim_create_namespace("collect")
	--vim.api.nvim_buf_set_extmark(bid, nid, 57, 0, { end_row = 58, hl_eol = true, hl_group = "Visual" })
	--vim.api.nvim_buf_clear_namespace(bid, nid, 0, -1)
end

---Navigates to the items source location.
function Item:show_source()
	if vim.fn.filereadable(self.path) == 1 then
		local lnum = tonumber(self.lnum)
		vim.cmd.edit(self.path)

		if lnum then
			vim.api.nvim_win_set_cursor(0, { lnum, 0 })
		end
	else
		vim.notify("File not found in current working directory.", vim.log.levels.ERROR)
	end
end

return M
