# Configuration

This is an overview over the supported configuration options:

```lua
opts = {
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
            -- Attach the match-list plugin to the buffer.
            require("match-list").attach(buffer)
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
    },

    -- Configuration options for the `:BuildTerm build` command.
    build = {
        -- The list of build commands.
        commands = {
            {
                -- The trigger filename or function.
                trigger = "filename",

                -- The command to send to the terminal to trigger the build.
                -- Can also be a list of commands to send in sequence.
                command = "make",

                -- The match group to select before running the command. Can
                -- also be a list to select multiple groups or `nil` to select
                -- the default group.
                match = "whatever",

                -- The priority of the builder, used to resolve conflicts between
                -- multiple builders (for example if you have a `Makefile`, but
                -- also a `Cargo.toml` file for Rust/cargo).
                priority = 0,

                -- Whether to reset the terminal prior to building.
                reset = true,
            },

            -- ...
        },

        -- Hook function that runs before every build.
        prepare = function()
            return true -- `true` to continue the build.
        end,

        -- `true` to issue :wa before every build.
        save_before_build = false,
    }
}
```

Builders can be defined as described in [builders](03-builders.md).
