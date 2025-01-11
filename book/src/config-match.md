# Match groups

_Match groups_ are groups of matchers that are used in a specific context. For example
there could be a _match group_ `rust` that matches error and warning messages from the
rust compiler, alongside other _match groups_ for other languages.

```lua
match = {
    default = {
        { [[\(error\|warning\|warn\|info\|debug\):\s*\(.*\)]], "type", "message" }
    },
    rust = {
        {
            { [[\(error\|warning\).*:\s*\(.*\)]], "type", "message" },
            { [[-->\s*\(.*\):\(\d\+\):\(\d\+\)]], "file", "lnum", "col" },
            priority = 1
        }
    }
}
```

Each _match group_ is defined by a list of _matchers_, that are used to match either
single lines or groups of consecutive lines. Each _matcher_ will produce a _match item_
when it matches a line.

A _match item_ is used to capture additional information about the match, such as line
numbers or filenames involved. The default field names used for this are:

| name      | description |
| --------- | ----------- |
| `type`    | The type of the match (`error`, `warning`, `info`, `debug`, `hint`, ...) |
| `message` | The message for the match. |
| `file`    | The name of the file that triggered the error / warning etc. |
| `lnum`    | The line number for the error. |
| `col`     | The column number for the error. |

This is mostly by convention though and you can define and use your own fields as well.

## Regular expressions

The simplest matcher consists of a single regular expression:

```lua
{ [[error: .*]] }
```

It will produce a _match item_ without any captured data and is pretty useless by itself.
However it can be useful to match lines without data during multi-line matches.

## Named groups

You can capture data from the match, by specifying a match group in the regular expression
and assigning a name to it. This is done by providing an additional string.

```lua
{ [[error: \(.*\)]], "message" }
```

This will create a field with the corresponding name in the _match item_. If you want to
test this, you can simulate matching a line in the NeoVim command line:

```lua
lua =require("build-term").test_match({ [[error: \(.*\)]], "message" }, "error: test")
```

The output should look similar to this:

```lua
{
    data = {
        message = "test"
    },
    length = 1,
    type = "hint"
}
```

## Match type

Note that the _match type_ in the above example is `hint`, but it should be `error`. You
can accomplish this in two ways. You can either directly specify the _match type_ like this:

```lua
{ [[error: \(.*\)]], "message", type = "error" }
```

Or you can have the match produce a corresponding field (if the line contains the type):

```lua
{ [[\(error\): \(.*\)]], "type", "message" }
```

## Lua functions

You can also use a Lua function, to match lines. For example:

```lua
{ function(line) return line:sub(1, 6) == "error:" end }
```

will match all lines that start with `"error:"`. If you want the match to return any
data, the function can return a table:

```lua
{ function(line)
    if line:sub(1, 6) == "error:" then
        return { message = line:sub(7) }
    end
end }
```

## Priority

If you have multiple matchers that match on the same line, you can use `priority` to
distinguish between them. For example:

```lua
{ [[error: \(.*\)]],       "message", type = "error", priority = 0 },
{ [[fatal error: \(.*\)]], "message", type = "fatal", priority = 1 },
```

## Multi-line matches

If you need to match multiple lines at once, you can specify multiple matchers like this:

```lua
{
    { [[\(error\|warning\).*:\s*\(.*\)]], "type", "message" },
    { [[-->\s*\(.*\):\(\d\+\):\(\d\+\)]], "file", "lnum", "col" },
    priority = 1
}
```

The results produced by all matchers are combined into a single _match item_.
