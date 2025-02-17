# Builders

Builders are used to conveniently run one of multiple pre-defined build-tools, based
on the make- or config files found in the current working directory.

```lua
build = {
    {
        match = "rust",
        trigger = "Cargo.toml",
        command = function(arg) return "cargo " .. (arg or "build") end,
        priority = 1,
    },
    {
        trigger = "Makefile",
        command = "make",
        priority = 0,
    },
    -- ...
}
```

When starting a build using `:BuildTerm build`, the list of builders is iterated in
priority order and the first builder that has a matching trigger is evaluated.

## Trigger

```lua
trigger = "Makefile"
```

If a `string` is provided as the trigger, the current working directory will be scanned
for a file with that name. If such a file is found, the trigger will match and the
builder will be executed (if no higher-priority builder exists).

```lua
trigger = function()
    -- ...
end
```

You can also provide a Lua function that returns `true` when the builder should be run
and `false` otherwise. This allows you to run more complex checks.

## Command

```lua
command = "make",
```

If a `string` is specified as the command, `build-term` will simply send that string,
followed by a return key press to the terminal on builder execution. If the user provides
any additional arguments to `:BuildTerm build`, such as `:BuildTerm build clean`, those
arguments will be appended to the provided command. Therefore a string like `"make"` can
be used to execute `"make"`, `"make clean"`, `"make doc"` etc.

```lua
command = { "echo Building...", "make" }
```

You can specify a table, to run multiple commands in sequence. Any provided arguments will
be appended to the *last* command in the sequence. Note that there is no error checking,
because the commands will be simply _typed_ one after the other into the terminal.

```lua
command = function(arg)
    return "cargo " .. (arg or "build")
end
```

## Match group

If you want to switch to a specific match group before running the build, you can provide
the `match` option to do so:

```lua
match = "rust",
command = function(arg) return "cargo " .. (arg or "build") end,
```

You can also provide multiple match groups:

```lua
match = { "rust", "cargo" }
```

## Priority

Sometimes you have projects with multiple build files. For example a rust project could
have a `Cargo.toml` file and a `Makefile`. You can specify the `priority` to resolve this.

## Reset

```lua
reset = true
```

By default, the terminal will be reset before every build triggered. You can disable this
with the `reset` option. Note that disabling `reset` will also mean that by default the
list of matches will contain old and new errors. Currently there is no way to mark old
match items as "seen" or clear them (other than cleaning the terminal contents by running
`"clear"`).
