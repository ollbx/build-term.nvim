# build-term.nvim

Toggleable terminal for neovim with error matching.

_Warning_: still in active development.

## Features

- Minimalistic and highly customizable.
- Error matching using regular expressions or lua functions.
- Support for matching multi-line error messages.
- Build command auto-detection (based on files or custom lua function).
- Multiple match configurations for different languages / build tools.

## Lazy.nvim setup example

```lua
return {
    "ollbx/build-term.nvim",
    cmd = "BuildTerm",
    opts = {
        match = {
            default = {
                {
                    match = { [[\(error\|warning\|warn\|info\|debug\):\s*\(.*\)]], "type", "message" }
                }
            },
            rust = {
                {
                    lines = {
                        { [[\(error\|warning\).*:\s*\(.*\)]], "type", "message" },
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
        { "[m",         "<cmd>BuildTerm prev<cr>", desc = "Previous build match" },
        { "]m",         "<cmd>BuildTerm next<cr>", desc = "Next build match" },
        { "[w",         "<cmd>BuildTerm prev warning,warn<cr>", desc = "Previous build warning" },
        { "]w",         "<cmd>BuildTerm next warning,warn<cr>", desc = "Next build warning" },
        { "[e",         "<cmd>BuildTerm prev error,fatal<cr>", desc = "Previous build error" },
        { "]e",         "<cmd>BuildTerm next error,fatal<cr>", desc = "Next build error" },
        { "<leader>bt", "<cmd>BuildTerm toggle<cr>", desc = "Toggle" },
        { "<leader>bo", "<cmd>BuildTerm focus<cr>", desc = "Open" },
        { "<leader>bb", "<cmd>BuildTerm build<cr>", desc = "Build" },
        { "<leader>bc", "<cmd>BuildTerm build clean<cr>", desc = "Clean" },
        { "<leader>bd", "<cmd>BuildTerm build doc<cr>", desc = "Build Docs" },
        { "<leader>bg", "<cmd>BuildTerm select-ui<cr>", desc = "Select match group" },
    }
}
```

## Match groups

`opts.match` is a table of match groups. The special group `default` is selected by
default. Any other group can be selected by:

- Calling `:BuildTerm select [group...]`
- Calling `:BuildTerm select-ui`
- Running a build with the `select = ...` option.

Each group consists of a list of matchers that are used to match terminal output.

## Matcher

A one-line matcher is specified by providing a value to the `match` key, whereas
multi-line use `lines = { match1, match2, ... }` to specify match on consecutive
lines. Note that `match = x` is equal to `lines = { x }`.

Matchers are evaluated against lines of output from the terminal and will produce
a `match item` on a successful match. A `match item` stores information related to
the match, such as the `message`, the line number `lnum` or the `type`.

### Simple regex

```lua
{ match = "something" }
{ match = [[error: \(.*\)]] }
```

Specifying a `string` value will interpret the string as a regular expression.
If the regular expression contains match groups, the text matched by the first match
group will be used as the `message` of the resulting match item.

Note: if you do not want to set `message`, you can use a non-capturing group, as in
`{ match = [[error: \%\(.*\)]] }`.

### Extended regex

```lua
{ match = { [[\(error\|warning\).*:\s*\(.*\)]], "type", "message" } }
```

By specifying a list of strings, you can assign names to multiple capture groups.
The matched values are assigned to the match item and can later be accessed, by
querying `item.data.[name]`.

There are a few special names that you can match:

| name       | description |
| ---------- | ----------- |
| `type`     | The type of the match (`error`, `warning`, `info`, `debug`, `hint`, ...) |
| `message`  | The message for the match. |
| `filename` | The name of the file that triggered the error / warning etc. |
| `lnum`     | The line number for the error. |
| `col`      | The column number for the error. |

### Lua function

You can also match the line using an arbitrary lua function:

```lua
{
    match = function(line)
        return line:sub(1, 6) == "error:"
    end
}
```

If the function returns a `boolean` value, it will just create an empty match item,
without any `message` or other metadata.

```lua
{
    match = function(line)
        if line:sub(1, 6) == "error:" then
            return { message = line:sub(7) }
        end
    end
}
```

But you can also return a table with additional data, similar to the match groups
with regular expressions.

## Navigation

Matched errors can be navigated by calling `:BuildTerm next` or `:BuildTerm prev`.
You can also filter for the type of the match by using `:BuildTerm next type`, where
`type` is either a type, such as `error` or a comma-separated list, such as `info,debug`.

Lua provides a bit more functionality through the `filter` option on `goto_next(config)` and
`goto_prev(config)`. It is also possible to implement your own navigation, by accessing the
matches with `get_matches()` and then calling `goto_match(match, config)` to navigate
to a specific match.

## Builders

You can configure several builders through `opts.build`. When a build is issued using the
`:BuildTerm build` command, the list of builders is iterated (ordered by descending priority).
The first builder that has a matching trigger will be selected for the build.

### Build triggers

The build trigger is specified using the `trigger` key. If the value is a `string`, it is
interpreted as a file name. The trigger matches, if the current working directory contains
a file with that name.

You can also specify a lua function returning a `boolean` to implement your own trigger.

### Build command

The `command` key specifies the build command that will be sent to the terminal. It can be
a simple string, such as `make`. Any additional argument provided to the `:BuildTerm build`
command will be appended to the command specified here. So `:BuildTerm build clean` will
run `make clean`.

You can also provide a lua function, that will receive the list of arguments (as a variadic
function) and run whatever string is returned by the function.

If `command` is a table (or the lua function returns a table), it is interpreted as a list
of commands to run in order. Note however, that there is no error checking. This will simply
send line-by-line input to the terminal.

### Other builder options

Other builder options of note are:

- `select` to specify the match group to switch to before starting the build. This can also
  be a list, to select multiple match groups.
- `priority` to resolve conflicts between multiple builders.
- `reset` can be set to `true` to reset the terminal before the build.
- `clear` can be set to `true` to clear the match list before the build.

## Customization examples

Coming soon...
