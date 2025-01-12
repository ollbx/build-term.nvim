# Command interface

The `:BuildTerm` command supports the following arguments:

| Command           | Description |
| ----------------- | ----------- |
| `toggle`          | Toggles the visibility of the _terminal window_. |
| `show`            | Opens the _terminal window_ without changing the window. |
| `open`            | Opens the _terminal window_ sets the window focus to it. |
| `close`           | Closes the _terminal window_. |
| `reset`           | Resets the terminal (restarts the shell, clears all matches). |
| `send [cmd]`      | Sends `[cmd]` as input to the terminal. |
| `next`            | Moves to the next _match item_. |
| `next [types]`    | Moves to the next _match item_ with the given _item type(s)_. |
| `prev`            | Moves to the previous _match item_. |
| `prev [types]`    | Moves to the previous _match item_ with the given _item type(s)_. |
| `goto`            | Moves to the _match item_ under the cursor in the terminal window. |
| `select`          | Selects the default _match group_. |
| `select [groups]` | Selects the specified _match group(s)_. |
| `select-ui`       | Uses `vim.ui.select` to ask for a _match group_ to select. |
| `build`           | Triggers the default build action. |
| `build [args]`    | Triggers the build action with additional arguments. |
| `quickfix`        | Sends the match list to the quickfix. |

This mostly corresponds to the [Lua interface](./lua.md).

