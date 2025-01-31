# Installation

Setup example for lazy.nvim:

```lua
return {
    -- Set up match-list (optional for error highlighting / navigation).
    {
        "ollbx/match-list.nvim",
        cmd = "MatchList",
        opts = {
            groups = {
                default = {
                    { [[\(error\|warning\|warn\|info\|debug\):\s*\(.*\)]], { "type", "message" } }
                },
                rust = {
                    {
                        { [[\(error\|warning\)[^:]*:\s*\(.*\)]], { "type", "message" } },
                        { [[-->\s*\(.*\):\(\d\+\):\(\d\+\)]], { "file", "lnum", "col" } }
                    }
                }
            },
        },
        keys = {
            { "[m",         "<cmd>MatchList prev<cr>", desc = "Previous build match" },
            { "]m",         "<cmd>MatchList next<cr>", desc = "Next build match" },
            { "[w",         "<cmd>MatchList prev warning warn<cr>", desc = "Previous build warning" },
            { "]w",         "<cmd>MatchList next warning warn<cr>", desc = "Next build warning" },
            { "[e",         "<cmd>MatchList prev error fatal<cr>", desc = "Previous build error" },
            { "]e",         "<cmd>MatchList next error fatal<cr>", desc = "Next build error" },
            { "<leader>bg", "<cmd>MatchList group<cr>", desc = "Select match group" },
        }
    },
    -- Set up build-term.
    {
        "ollbx/build-term.nvim",
        cmd = "BuildTerm",
        opts = {
            build = {
                save_before_build = true,

                commands = {
                    {
                        match = "rust",
                        trigger = "Cargo.toml",
                        command = function(arg) return "cargo " .. (arg or "build") end,
                        priority = 2,
                    },
                    {
                        match = "default",
                        trigger = "Makefile",
                        command = "make",
                    }
                }
            }
        },
        keys = {
            { "<leader>bt", "<cmd>BuildTerm toggle<cr>", desc = "Toggle" },
            { "<leader>bo", "<cmd>BuildTerm open<cr>", desc = "Open" },
            { "<leader>bb", "<cmd>BuildTerm build<cr>", desc = "Build" },
            { "<leader>bc", "<cmd>BuildTerm build clean<cr>", desc = "Clean" },
            { "<leader>bd", "<cmd>BuildTerm build doc<cr>", desc = "Build docs" },
            { "<leader>br", "<cmd>BuildTerm reset<bar>BuildTerm open<cr>", desc = "Resets the terminal" },
            { "<leader>bq", "<cmd>BuildTerm close<bar>MatchList quickfix<cr>", desc = "Send to quickfix" },
        }
    }
}
```

Note: the `match-list` plugin will perform matching, highlighting and error
navigation, while `build-term` will provide the toggle-able terminal and build
actions.

- Please refer to the [match-list documentation](https://github.com/ollbx/match-list.nvim/blob/main/doc/01-installation.md)
  for information on how to set up error / warning matching.
- You can find an overview of the configuration options under [setup](02-configuration.md).
- For the `:BuildTerm` command, please refer to [command](04-command.md).
- For the Lua API see [API](05-lua-api.md).
