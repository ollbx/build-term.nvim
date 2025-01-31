local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = { 

		{
			"rebelot/kanagawa.nvim",
			config = function()
				vim.cmd.colorscheme("kanagawa")
			end
		},
		{
			"nvim-lualine/lualine.nvim",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			opts = {}
		},
		{
			"nvim-telescope/telescope.nvim",
			dependencies = { "nvim-lua/plenary.nvim" }
		},
		{
			"stevearc/dressing.nvim",
			opts = {}
		},
		{
			"ollbx/match-list.nvim",
			cmd = "MatchList",
			opts = {
				groups = {
					default = {},
					rust = {
						{
							{ [[\(error\|warning\)[^:]*:\s*\(.*\)]], { "type", "message" } },
							{ [[-->\s*\(.*\):\(\d\+\):\(\d\+\)]], { "file", "lnum", "col" } }
						}
					}
				},
			}
		},
		{
			"ollbx/build-term.nvim",
			cmd = "BuildTerm",
			opts = {
				build = {
					commands = {
						{
							match = "rust",
							trigger = "Cargo.toml",
							command = function(arg) return "cargo " .. (arg or "build") end,
						}
					}
				},
				terminal = {
					window = function()
						return {
							split = "below",
							height = math.floor(vim.o.lines * 0.4),
						}
					end
				}
			}
		}
	}
})

vim.o.nu = true
vim.o.relativenumber = true

vim.keymap.set("t", "<esc>", "<C-\\><C-n>", {})
