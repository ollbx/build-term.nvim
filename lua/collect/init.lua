local Item = require("collect.item")
local M = {}

---@class Collect.Options
---@field match Collect.MatchConfig[]

---Sets up the plugin.
---@param opts Collect.Options|nil The configuration options.
function M.setup(opts)
	if opts then
		---@type Collect.MatchConfig[]
		M.match = opts.match
	else
		M.match = {}
	end

	---@type Collect.Item[] The set of items found.
	M.items = {}
	---@type boolean[] The set of known item keys.
	M.known = {}
	---@type integer The current navigation index.
	M.index = 0
end

function M.attach()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.notify("Attaching to buffer " .. bufnr)

	vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function(_, _, _, first, last)
			local items = Item.match(bufnr, first, last, M.match)
			local new_item = false

			for _, item in ipairs(items) do
				if not M.known[item.key] then
					table.insert(M.items, item)
					M.known[item.key] = true
					new_item = true
				end
			end

			if new_item then
				-- Sort that stuff.
				table.sort(M.items, function(l, r)
					return l.key < r.key
				end)
			end
		end
	})
end

function M.next()
	M.index = math.min(M.index + 1, #M.items)
	M.goto()
end

function M.prev()
	M.index = math.max(M.index - 1, 1)
	M.goto()
end

function M.goto()
	local item = M.items[M.index]

	if item then
		item:show_message()
		vim.notify("Showing item " .. M.index)
	else
		vim.notify("No item found", vim.log.levels.WARN)
	end
end

return M
