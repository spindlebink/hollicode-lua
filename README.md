# Hollicode for Lua

A Hollicode bytecode interpreter written in Lua and still in construction. Moving alongside the language itself.

This interpreter is meant to serve as a reference implementation. It implements Hollicode's entire instruction set in a framework-agnostic and generally Lua-idiomatic way.

Included in this repository is a basic LÖVE-based visual runner for Hollicode scripts. It can be used as a jumping-off point for integrating the interpreter in your projects if you want. The example program (and accompanying Hollicode script) isn't super sophisticated by any means, but it's a real-world example of running bytecode and getting its results.

## Usage

The library you'll use for your own projects can be found at `lib/hollicode.lua`. It's my working Hollicode bytecode interpreter.

If you include `lib/json.lua` or an API-compatible JSON reader (needs to expose `json.decode`) in the same directory as `hollicode.lua`, the interpreter will support JSON-formatted bytecode as well as plaintext.

```lua
local HollicodeInterpreter = require("lib.hollicode")

local interpreter = HollicodeInterpreter:new()
interpreter:loadFile("compiled_script.json")

-- Table of variables used when getting a variable from Hollicode script
interpreter.variables["custom_variable"] = 20
interpreter.variables["progress_flag"] = true

interpreter.callbacks.echo = function(self, str)
	-- Push `str` to the text buffer, however your game implements it.
end

interpreter.callbacks.option = function(self, params)
	-- `params` is a table of all parameters passed to the option directive.
	-- In this callback you might add the requested option to a list of buttons.
end

interpreter.callbacks.wait = function(self)
	-- Called when the interpreter reaches `wait`. You might await user input or
	-- you might proceed however your game demands.
end

-- Run the interpreter until the next `wait` command or until it terminates.
interpreter:go()

-- Here we've got a function intended to be called when the user selects the
-- option they're proceeding from.
local function onOptionSelected(index)
	-- `index` corresponds to the option you want the interpreter to go to.
	-- In the script
	-- ```
	-- [option] Option #1
	--     Option contents
	-- [option] Option #2
	--     Option contents
	-- [option] Option #3
	--     Option contents
	-- ```
	-- you'd be able to call `goToOption(1)`, `goToOption(2)`, or `goToOption(3)`,
	-- for example.
	interpreter:goToOption(index)

	-- Continue the interpreter from its current point.
	interpreter:go()
end
```

## Limitations

The Hollicode compiler currently dumps text strings to ASCII when generating a plain-text bytecode file, including special characters. The Lua interpreter handles some escape sequences (e.g. white space escapes), but doesn't handle Unicode `\u` sequences. If you need special characters, use the JSON bytecode format.

The compiler may change in the future to output unescaped UTF-8.

## License

**The interpreter** (`lib/hollicode.lua`) is licensed MIT. It optionally depends on RXI's `json.lua`, also included in this repository, also licensed MIT.

**The LÖVE project** (the rest of the stuff in this repo) is licensed AGPL 3.0.
