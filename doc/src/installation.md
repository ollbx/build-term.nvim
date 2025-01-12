# Installation

## lazy.nvim example

You can set up `build-term.nvim` using `lazy.nvim` as follows:

```lua
return {
    "ollbx/build-term.nvim",
    cmd = "BuildTerm",
    opts = {
        match = {
            default = {
                { [[\(error\|warning\|info\):\s*\(.*\)]], "type", "message" }
            },
            rust = {
                {
                    priority = 1,
                    { [[\(error\|warning\)[^:]*:\s*\(.*\)]], "type", "message" },
                    { [[-->\s*\(.*\):\(\d\+\):\(\d\+\)]], "file", "lnum", "col" },
                }
            }
        },
        build = {
            commands = {
                {
                    select = "rust",
                    trigger = "Cargo.toml",
                    command = function(arg) return "cargo " .. (arg or "build") end,
                    priority = 2,
                },
                {
                    select = "default",
                    trigger = "Makefile",
                    command = "make",
                }
            }
        }
    },
    keys = {
        { "[m", "<cmd>BuildTerm prev<cr>", desc = "Previous build match" },
        { "]m", "<cmd>BuildTerm next<cr>", desc = "Next build match" },
        { "[w", "<cmd>BuildTerm prev warning warn<cr>", desc = "Previous build warning" },
        { "]w", "<cmd>BuildTerm next warning warn<cr>", desc = "Next build warning" },
        { "[e", "<cmd>BuildTerm prev error fatal<cr>", desc = "Previous build error" },
        { "]e", "<cmd>BuildTerm next error fatal<cr>", desc = "Next build error" },
        { "<leader>bt", "<cmd>BuildTerm toggle<cr>", desc = "Toggle" },
        { "<leader>bo", "<cmd>BuildTerm open<cr>", desc = "Open" },
        { "<leader>bb", "<cmd>BuildTerm build<cr>", desc = "Build" },
        { "<leader>bc", "<cmd>BuildTerm build clean<cr>", desc = "Clean" },
        { "<leader>bd", "<cmd>BuildTerm build doc<cr>", desc = "Build docs" },
        { "<leader>bg", "<cmd>BuildTerm select-ui<cr>", desc = "Select match group" },
        { "<leader>bq", "<cmd>BuildTerm quickfix<cr>", desc = "Send to quickfix" },
        { "<leader>bx", "<cmd>BuildTerm clear<cr>", desc = "Clears the list of matches" },
    }
}
```

Right now there are no predefined match or build configurations. So if you leave
`match` and `build` empty, the terminal will perform no matching and the build action
will not trigger anything.
