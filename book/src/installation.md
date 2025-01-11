# Installation

## lazy.nvim example

```lua
return {
  "ollbx/build-term.nvim",
  cmd = "BuildTerm",
  opts = {
    match = {
      default = {
        {
          match = {
            [[\(error\|warning\|warn\|info\|debug\):\s*\(.*\)]],
            "type", "message"
          }
        }
      },
      rust = {
        {
          lines = {
            { [[\(error\|warning\)[^:]*:\s*\(.*\)]], "type", "message" },
            { [[-->\s*\(.*\):\(\d\+\):\(\d\+\)]], "filename", "lnum", "col" }
          },
        }
      }
    },
    build = {
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
  },
  keys = {
    { "[m", "<cmd>BuildTerm prev<cr>", desc = "Previous build match" },
    { "]m", "<cmd>BuildTerm next<cr>", desc = "Next build match" },
    { "[w", "<cmd>BuildTerm prev warning,warn<cr>", desc = "Previous build warning" },
    { "]w", "<cmd>BuildTerm next warning,warn<cr>", desc = "Next build warning" },
    { "[e", "<cmd>BuildTerm prev error,fatal<cr>", desc = "Previous build error" },
    { "]e", "<cmd>BuildTerm next error,fatal<cr>", desc = "Next build error" },
    { "<leader>bt", "<cmd>BuildTerm toggle<cr>", desc = "Toggle" },
    { "<leader>bo", "<cmd>BuildTerm focus<cr>", desc = "Open" },
    { "<leader>bb", "<cmd>BuildTerm build<cr>", desc = "Build" },
    { "<leader>bc", "<cmd>BuildTerm build clean<cr>", desc = "Clean" },
    { "<leader>bd", "<cmd>BuildTerm build doc<cr>", desc = "Build docs" },
    { "<leader>bg", "<cmd>BuildTerm select-ui<cr>", desc = "Select match group" },
  }
}
```
