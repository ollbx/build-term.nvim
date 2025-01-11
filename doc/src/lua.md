# Lua interface

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

    -- Overrides the corresponding setting in `opts.terminal`.
    window = ...,
    on_init = ...
    on_focus = ...,
}
```

You can also query the current terminal state:

```lua
M.is_open()    -- Returns `true` when the terminal is open.
M.is_focused() -- Returns `true` when the terminal is focused.
```

## Managing the match groups

```lua
M.get_groups()             -- Returns the list of all available match groups.
M.get_selected_groups()    -- Returns the list of currently selected match groups.
M.select()                 -- Selects the default group.
M.select(group)            -- Selects the given group.
M.select(group_a, group_b) -- Selects multiple groups.
M.select_ui()              -- Selects the group using `vim.ui.select`.
M.rebuild_matches()        -- Rescans the output for matches.
                           -- This will usually happen automatically.
```

## Managing the list of matches

```lua
M.clear_matches()       -- Clears the list of matches / selection / highlights etc.
M.clear_selected_mark() -- Removes the highlight of the currently selected match.
M.get_current()         -- Returns the currently selected match item.
M.get_matches()         -- Returns a list of current match items.
```

You can navigate between matches using:

```lua
M.goto_next(config)         -- Go to the next match.
M.goto_prev(config)         -- Go to the previous match.
M.goto_match(match, config) -- Go to a specific match.
```

`config` is either `nil` or a table:

```lua
local config = {
    -- Can be used to filter match items by any function for the goto_next
    -- and goto_prev function.
    filter = function(item)
        return item.type == "error"
    end,

    -- Can be used to customize the status message printed. The function is
    -- also called without arguments, when no more matches are available.
    notify = function(index, total, item)
        if index then
            vim.notify(item.data.message)
        else
            vim.notify("No item found", vim.log.levels.WARN)
        end
    end,

    -- Controls whether the navigation will set the view window to the current
    -- window before opening a file.
    update_view = true,

    -- Controls if the source location in the terminal window should be highlighted.
    -- The highlight can be cleared by M.clear_selected_mark().
    mark_source = true,

    -- Controls if the cursor moves to the source location in the terminal window.
    goto_source = true,

    -- Controls if the target location / file is opened in the view window.
    goto_target = true,
}
```

_Note_: you can implement your own navigation using `M.get_matches()` and `M.goto_match()`.

## Building

```lua
M.build()    -- Triggers the first matching builder with the default action.
M.build(...) -- Triggers the first matching builder and passes all arguments to it.
```

## Debugging

```lua
M.test_match(config, line) -- Tries to match line against the given match config.
```
