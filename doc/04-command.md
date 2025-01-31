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

You have more control over the behavior of those commands, by using the
corresponding functions in the [Lua API](05-lua-api.md).
