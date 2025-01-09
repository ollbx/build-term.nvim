# toggle-term.nvim

Toggleable terminal for neovim with error matching.

_Warning_: still in active development.

## Features

- Minimalistic and highly customizable.
- Error matching using regular expressions or lua functions.
- Support for matching multi-line error messages.
- Build command auto-detection (based on files or custom lua function).
- Multiple match configurations for different languages / build tools.

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
		{ "[m",         "<cmd>BuildTerm prev<cr>", desc = "Previous build match" },
		{ "]m",         "<cmd>BuildTerm next<cr>", desc = "Next build match" },
		{ "[e",         "<cmd>BuildTerm prev error,fatal<cr>", desc = "Previous build error" },
		{ "]e",         "<cmd>BuildTerm next error,fatal<cr>", desc = "Next build error" },
		{ "<leader>bt", "<cmd>BuildTerm toggle<cr>", desc = "Toggle" },
		{ "<leader>bo", "<cmd>BuildTerm focus<cr>", desc = "Open" },
		{ "<leader>bb", "<cmd>BuildTerm build<cr>", desc = "Build" },
		{ "<leader>bc", "<cmd>BuildTerm build clean<cr>", desc = "Clean" },
		{ "<leader>bd", "<cmd>BuildTerm build doc<cr>", desc = "Build Docs" },
	}
}
```

## Customization examples

Coming soon...
