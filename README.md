# Hollicode for Lua

A Hollicode bytecode interpreter written in Lua and still in construction. Moving alongside the language itself.

This interpreter is meant to serve as a reference implementation. It implements Hollicode's entire instruction set in a framework-agnostic and generally Lua-idiomatic way.

Included in this repository is a basic LÖVE-based visual runner for Hollicode scripts. It can be used as a jumping-off point for integrating the interpreter in your projects if you want.

## Limitations

The Hollicode compiler currently dumps text strings to ASCII when generating a plain-text bytecode file, including special characters. The Lua interpreter handles some escape sequences (e.g. white space escapes), but doesn't handle Unicode `\u` sequences. If you need special characters, use the JSON bytecode format.

The compiler may change in the future to output unescaped UTF-8.

## License

**The interpreter** (`lib/hollicode.lua`) is licensed MIT. It optionally depends on RXI's `json.lua`, also included in this repository, also licensed MIT.

**The LÖVE project** (the rest of the stuff in this repo) is licensed AGPL 3.0.
