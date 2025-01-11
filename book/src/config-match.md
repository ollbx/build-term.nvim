# Match groups

```lua
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
  }
}
```

`opts.match` is a table of match groups. The special group `default` is selected by
default. Any other group can be selected by:

- Calling `:BuildTerm select [group...]`
- Calling `:BuildTerm select-ui`
- Running a builder with the `select = ...` option.

Each group consists of a list of matchers that are used to match terminal output.

## Matchers

```lua
{ match = "something" }
{ lines = { "something", match2, ... } }
```

A one-line matcher is specified by providing a value to the `match` key, whereas
multi-line matchers use `lines = { match1, match2, ... }` to specify required matches
on consecutive lines. Note that `match = x` is equal to `lines = { x }`.

Matchers are evaluated against lines of output from the terminal and will produce
a _match item_ on a successful match. A _match item_ stores information related to
the match, such as the `message`, the line number `lnum` or the `type`.

### Match a regex without named groups

```lua
"something"
[[error: \(.*\)]]
```

Specifying a `string` value will interpret the string as a regular expression.
If the regular expression contains match groups, the text matched by the first match
group will be used as the `message` of the resulting match item.

*Note*: you can suppress this with a non-capturing group, such as: `[[error: \%\(.*\)]]`.

### Match a regex with named groups

```lua
{ [[\(error\|warning\).*:\s*\(.*\)]], "type", "message" }
```

By specifying a list of strings, you can assign names to multiple capture groups.
The matched values are assigned to the match item and can be accessed in lua code using
`item.data.[name]` (see `get_matches()`).

*Note*: you can use non-capturing groups `\%\(...\)` if you need a group without a name.

There are a few special names that you can match:

| name       | description |
| ---------- | ----------- |
| `type`     | The type of the match (`error`, `warning`, `info`, `debug`, `hint`, ...) |
| `message`  | The message for the match. |
| `filename` | The name of the file that triggered the error / warning etc. |
| `lnum`     | The line number for the error. |
| `col`      | The column number for the error. |

### Match using a lua function

You can also match the line using an arbitrary lua function:

```lua
function(line)
    return line:sub(1, 6) == "error:"
end
```

If the function returns a `boolean` value, it will just create an empty match item,
without any `message` or other metadata.

```lua
function(line)
    if line:sub(1, 6) == "error:" then
        return { message = line:sub(7) }
    end
end
```

But you can also return a table with additional data, similar to the match groups
with regular expressions.
