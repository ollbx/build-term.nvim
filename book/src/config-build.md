## Builders

```lua
build = {
    {
        select = "rust",
        trigger = "Cargo.toml",
        command = function(arg) return "cargo " .. (arg or "build") end,
        priority = 2,
    },
    -- ...
}
```

You can configure several builders through `opts.build`. When a build is started using the
`:BuildTerm build` command, the list of builders is iterated (by priority). The first builder
that has a matching trigger will be selected for the build.

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

Other builder options are:

- `select` to specify the match group to switch to before starting the build. This can also
  be a list, to select multiple match groups.
- `priority` to resolve conflicts between multiple builders.
- `reset` can be set to `true` to reset the terminal before the build.
- `clear` can be set to `true` to clear the match list before the build.
