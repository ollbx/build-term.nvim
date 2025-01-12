# build-term.nvim

[![Tests](https://github.com/ollbx/build-term.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/ollbx/build-term.nvim/actions/workflows/ci.yml) [![Docs](https://github.com/ollbx/build-term.nvim/actions/workflows/mdbook.yml/badge.svg)](https://ollbx.github.io/build-term.nvim/)

Toggleable terminal for neovim with error matching.

_Warning_: still in active development.

[demo.webm](https://github.com/user-attachments/assets/b5f86474-8797-4169-8b39-17c302b7092c)

## Features

- Minimalistic and highly customizable.
- Error matching using regular expressions or lua functions.
- Support for matching multi-line error messages.
- Build command auto-detection (based on files or custom lua function).
- Multiple match configurations for different languages / build tools.

## Documentation

Check out the [documentation](https://ollbx.github.io/build-term.nvim/).

## TODO

- [ ] Send the matched items to the quickfix list.
- [ ] Predefined commands / matchers for common languages?
- [ ] Test it in Linux.
- [ ] Test what happens to match items when the terminal is cleared...
