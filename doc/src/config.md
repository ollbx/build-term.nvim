# Configuration

```lua
opts = {
    -- The table of match groups.
    match = {
        -- The default group which is automatically selected.
        default = {
            -- ...
        },

        -- The group "whatever" specified by a list of matchers.
        whatever = {
            {
                -- Matcher line 1.
                -- Note: the curly brackets can be omitted for the first line.
                { [[error:\s*\(.*\)]], "message" },

                -- Matcher line 2.
                { [[in: \(.*\):\(\d+\)]], "file", "lnum" },

                -- There could be more lines here.
                -- ...

                -- The type of the match. You can specify this, if the match
                -- itself does not return a match type.
                type = "error", -- error,err,warning,warn,info,debug,hint,...

                -- Can be set to resolve situations, where multiple matchers
                -- will match on the same line.
                priority = 0,
            },
            {
                -- Single-line match.
                [[error:\s*\(.*\) in \(.*\)]], "message", "file",
                priority = 1,
            }
            -- ...
        }
    },

    -- Configuration options related to the terminal window.
    terminal = {
        -- The shell to run. Same as ":term [shell]". You can also specify a
        -- function for example if you want to detect the OS.
        shell = nil,

        -- Overrides for the terminal window. Can be a table or a function.
        window = function()
            return {
                split = "below",
                height = math.floor(vim.o.lines / 4),
            }
        end,

        -- Hook function called when initializing the terminal buffer.
        init_buffer = function(buffer)
            vim.keymap.set("n", "<cr>", "<cmd>:BuildTerm goto<cr>", { buffer = buffer })
        end,

        -- Hook function called when initializing the terminal window.
        -- The window is active, when the function is called.
        init_window = function(_window)
            vim.opt_local.nu = false
            vim.opt_local.relativenumber = false
        end,

        -- Hook function called when the terminal window receives the focus
        -- through the toggle or open functions.
        on_focus = function()
            vim.cmd.startinsert()
        end,

        -- Allows overriding the extmark configuration for a match.
        extmark_config = function(match)
            -- Use this if you want to customize highlighting etc.
            -- See `vim.api.nvim_buf_set_extmark` for options.
            -- You should inspect `match.type` and return something like:
            -- { sign_text = "E", sign_hl_group = "DiagnosticSignError" }
        end
    },

    -- Configuration options related to the view window.
    view = {
        -- Allows customizing the navigation to the error file.
        -- _Warning_: setting this will override the default behavior.
        open = function(match)
            -- Try to open `match.data.file` in the current window.
            -- This is intended to allow customizing the path searching mechanism.
            -- See `view.lua` for the default implementation.
            -- Return `true` on success.
        end,

        -- Allows customizing the navigation to the error position.
        -- _Warning_: setting this will override the default behavior.
        goto = function(match)
            -- Set the cursor to `match.data.lnum` and `match.data.col`.
        end

        -- Allows customizing the initial view window selection.
        -- _Warning_: setting this will override the default behavior.
        find_view = function()
            -- If there is no current view window, this is called to determine
            -- the view window to use. The default implementation simply finds
            -- the largest window and uses it.
            -- You could also open a split here and use that as the view window.
        end
    },

    -- Configuration options for the `:BuildTerm build` command.
    -- This is a list of builders.
    build = {
        {
            -- The trigger filename or function.
            trigger = "filename",

            -- The command to send to the terminal to trigger the build.
            -- Can also be a list of commands to send in sequence.
            command = "make",

            -- The match group to select before running the command. Can
            -- also be a list to select multiple groups or `nil` to select
            -- the default group.
            select = "whatever",

            -- The priority of the builder, used to resolve conflicts between
            -- multiple builders (for example if you have a `Makefile`, but
            -- also a `Cargo.toml` file for Rust/cargo).
            priority = 0,

            -- Whether to reset the terminal prior to building.
            reset = true,

            -- Whether to clear the list of matches prior to building. Note:
            -- if you do not reset the terminal, but clear the match list, only
            -- new output should produce matches. However this will currently
            -- pick up matches from previous commands, due to how the output of
            -- the terminal is scanned. That is a known issue.
            clear = true,
        },

        -- ...
    }

    -- Determines whether to rebuild / rescan the match list after selecting a
    -- different match group.
    select_rebuild = true,
}
```
