# Lua API

```lua
local M = require("build-term")
```

## Open / close / toggle the terminal

```lua
M.show(config)   -- Opens the terminal without focusing on it.
M.open(config)   -- Opens the terminal and changes focus to it.
M.toggle(config) -- Toggles the terminal.
M.close()        -- Closes the terminal.
M.reset()        -- Resets the terminal.
```

`config` is either `nil` or a table:

```lua
local config = {
    -- Specifies if the terminal should be focused. Primarily used for the
    -- toggle command. `show({ focus = true })` is essentially the same as
    -- `open()`.
    focus = true,

    -- Overrides the corresponding setting in `opts.terminal` (see 02-configuration.md).
    window = ...,
    init_buffer = ...,
    init_window = ...,
    on_focus = ...,
}
```

You can also query the current terminal state:

```lua
M.is_open()    -- Returns `true` when the terminal is open.
M.is_focused() -- Returns `true` when the terminal is focused.
```

## Building

```lua
M.build()    -- Triggers the first matching builder with the default action.
M.build(...) -- Triggers the first matching builder and passes all arguments to it.
```
