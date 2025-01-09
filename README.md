# toggle-term.nvim

Currently in development...

## Lazy.nvim setup example

```lua
return {
	"ollbx/build-term.nvim",
	cmd = "BuildTerm",
	opts = {
		match = {
			default = {
				{
					type = "error",
					match = { "error:\\s*\\(.*\\)", "message" }
				}
			},
			rust = {
				{
					type = "warn",
					match = { [[^[Ww]arn\%\(ing\)\?:\(.*\)]], "message" }
				},
				{
					type = "error",
					lines = {
						{ [[error.*: \(.*\)]],              "message" },
						{ [[--> \(.*\):\(\d\+\):\(\d\+\)]], "filename", "lnum", "col" }
					},
				}
			}
		},
		build = {
			{
				select = "rust",
				trigger = "Cargo.toml",
				command = function(arg) return "cargo " .. (arg or "build") end
			}
		}
	},
	keys = {
		{ "<leader>bp", "<cmd>BuildTerm prev<cr>", desc = "Go to previous" },
		{ "<leader>bn", "<cmd>BuildTerm next<cr>", desc = "Go to next" },
		{ "<leader>bt", "<cmd>BuildTerm toggle<cr>", desc = "Toggle" },
		{ "<leader>bo", "<cmd>BuildTerm open-focus<cr>", desc = "Open" },
		{ "<leader>bb", "<cmd>BuildTerm build<cr>", desc = "Build" },
		{ "<leader>bc", "<cmd>BuildTerm build clean<cr>", desc = "Clean" },
		{ "<leader>bd", "<cmd>BuildTerm build doc<cr>", desc = "Doc" },
	}
}
```
