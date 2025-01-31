# build-term.nvim

Toggleable terminal for neovim with error matching.

_Warning_: still in active development.

[demo.webm](https://github.com/user-attachments/assets/09b98eab-0a23-416b-9457-f4fb12d2731e)

## Features

- Minimalistic and highly customizable.
- Error matching using [match-list.nvim](https://github.com/ollbx/match-list.nvim).
  - Navigation between matches across different files.
  - Matches can also be sent to the quickfix.
  - Multiple match configurations for different languages / build tools.
- Build command auto-detection (based on files or custom lua function).

## Documentation

See [installation](doc/01-installation.md) to get started.

## TODO

- [ ] Predefined commands / matchers for common languages?
