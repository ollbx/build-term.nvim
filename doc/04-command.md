# Command interface

The plugin provides a `:BuildTerm` command that provides the following functions:

| Command           | Description |
| ----------------- | ----------- |
| `toggle`          | Toggles the visibility of the _terminal window_. |
| `show`            | Opens the _terminal window_ without changing the window. |
| `open`            | Opens the _terminal window_ sets the window focus to it. |
| `close`           | Closes the _terminal window_. |
| `reset`           | Resets the terminal (restarts the shell, clears all matches). |
| `send [cmd]`      | Sends `[cmd]` as input to the terminal. |
| `build`           | Triggers the default build action. |
| `build [args]`    | Triggers the build action with additional arguments. |

It also re-exports some of the `:MatchList` commands for consistency:

| Command           | Description |
| ----------------- | ----------- |
| `goto`            | Navigates to the match item under the cursor. |
| `first`           | Navigates to the first match item. |
| `last`            | Navigates to the last match item. |
| `next`            | Navigates to the next match item. |
| `next [types]`    | Navigates to the next match item with any of the given types. |
| `prev`            | Navigates to the previous match item. |
| `prev [types]`    | Navigates to the previous match item with any of the given types. |
| `cancel`          | Cancels the current item selection. |
| `select`          | Shows the match groups using `vim.ui.select`. Enter switches the global match group. |
| `select [names]`  | Sets the global match group(s) to the given group(s). |
| `lselect`         | Shows the match groups using `vim.ui.select`. Enter switches the (buffer-)local match group. |
| `lselect [names]` | Sets the (buffer-)local match group(s) to the given group(s). |
| `quickfix`        | Sends the matched items to the quickfix list. |

You have more control over the behavior of those commands, by using the
corresponding functions in the [Lua API](05-lua-api.md).
