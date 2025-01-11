# Usage

## Navigation

Matched errors can be navigated by calling `:BuildTerm next` or `:BuildTerm prev`.
You can also filter for the type of the match by using `:BuildTerm next type`, where
`type` is either a type, such as `error` or a comma-separated list, such as `info,debug`.

Lua provides a bit more functionality through the `filter` option on `goto_next(config)` and
`goto_prev(config)`. It is also possible to implement your own navigation, by accessing the
matches with `get_matches()` and then calling `goto_match(match, config)` to navigate
to a specific match.
