-- hollicode.lua
-- 
-- Hollicode bytecode interpreter. For more info:
-- * `https://github.com/spindlebink/hollicode`
-- * `https://github.com/spindlebink/hollicode-lua`
--
-- Copyright © 2021-2022 Stanaforth (@spindlebink).
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the “Software”), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local HollicodeInterpreter = {}

local requirePath = (...):match("(.-)%hollicode")
local hasJSON, json = pcall(require, requirePath .. "json")

local NIL_CONSTANT = {}
local table_insert = table.insert
local table_remove = table.remove
local type = type
local unpack = unpack

local supportedBytecodeVersions = {
	["0.1.0"] = true
}

HollicodeInterpreter.ignoreTextBytecodeHeader = false

-- Operator function table
local operators = {
	[">"] = function(left, right) return left > right end,
	["<"] = function(left, right) return left < right end,
	[">="] = function(left, right) return left >= right end,
	["<="] = function(left, right) return left <= right end,
	["=="] = function(left, right) return left == right end,
	["!="] = function(left, right) return left ~= right end,
	["&&"] = function(left, right) return not not (left and right) end,
	["||"] = function(left, right) return not not (left or right) end,
	["+"] = function(left, right) return left + right end,
	["-"] = function(left, right) return left - right end,
	["/"] = function(left, right) return left / right end,
	["*"] = function(left, right) return left * right end
}

-- Instructions
local instructionExecution = {
	["RET"] = function(self)
		self:_return()
	end,

	["POP"] = function(self)
		self:_pop()
		self:_advance()
	end,

	["JMP"] = function(self, amount)
		self:_advance(amount)
	end,

	["FJMP"] = function(self, amount)
		if self:_peek() == NIL_CONSTANT or not self:_peek() then
			self:_advance(amount)
		else
			self:_advance()
		end
	end,

	["TJMP"] = function(self, amount)
		self:_pushTraceback()
		self:_advance(amount)
	end,

	["STR"] = function(self, constant)
		self:_push(constant)
		self:_advance()
	end,

	["NUM"] = function(self, constant)
		self:_push(constant)
		self:_advance()
	end,

	["BOOL"] = function(self, constant)
		self:_push(constant)
		self:_advance()
	end,

	["NIL"] = function(self)
		self:_push(NIL_CONSTANT)
		self:_advance()
	end,

	["GETV"] = function(self, name)
		if self.variables[name] == nil then
			self:_push(NIL_CONSTANT)
		else
			self:_push(self.variables[name])
		end
		self:_advance()
	end,

	["LOOK"] = function(self)
		local parent = self:_pop()
		local child = self:_pop()
		self:_push(parent[child])
		self:_advance()
	end,

	["NOT"] = function(self)
		if self._stack[#self._stack] == NIL_CONSTANT then
			self._stack[#self._stack] = true
		else
			self._stack[#self._stack] = not self._stack[#self._stack]
		end
		self:_advance()
	end,

	["NEG"] = function(self)
		self._stack[#self._stack] = -self._stack[#self._stack]
		self:_advance()
	end,

	["BOP"] = function(self, op)
		local left = self:_pop()
		local right = self:_pop()
		local val = operators[op](left, right)
		self:_push(val)
		self:_advance()
	end,

	["CALL"] = function(self, numArgs)
		local args = {}
		local method = self:_pop()
		for i = 1, numArgs do
			table_insert(args, self:_pop())
		end
		if self.yieldAtFunctionCall then
			self._yield = true
		end
		if self.callbacks.functionCall then
			self.callbacks.functionCall(self, method, args)
		else
			if method and method ~= NIL_CONSTANT then
				method(unpack(args))
			else
				error("interpreter could not call method. Ensure that you have implemented either `callbacks.functionCall` or provided a valid function handle.")
			end
		end
		self:_advance()
	end,

	["ECHO"] = function(self)
		local top = self:_pop()
		self:_emitEcho(top)
		self:_advance()
	end,

	["OPT"] = function(self, numArgs)
		local args = {}
		for i = 1, numArgs do
			table_insert(args, self:_pop())
		end
		self:_emitOption(args)
		self:_advance()
	end,

	["WAIT"] = function(self)
		self._yield = true
		self:_emitWait()
		self:_advance()
	end
}

-- Creates a new Hollicode interpreter.
function HollicodeInterpreter:new()
	self.__index = self
	local interpreter = {}

	interpreter.yieldAtFunctionCall = false

	interpreter.callbacks = {}
	interpreter.variables = {}

	interpreter._ip = 1
	interpreter._stack = {}
	interpreter._traceback = {}

	interpreter._options = {}
	interpreter._bytecodeHeader = nil
	interpreter._instructions = nil

	setmetatable(interpreter, self)

	return interpreter
end

-- Loads a file.
function HollicodeInterpreter:loadFile(filename, mode)
	if not mode then
		mode =
			filename:sub(-4) == "hlcj" and "json" or
			filename:sub(-4) == "hlct" and "text" or
			error("unrecognized file type on '" .. filename .. "'")
	end
	if mode == "json" and not hasJSON then
		error("cannot load JSON unless `json.lua` has been loaded -- place `json.lua` in the same directory as `hollicode.lua` to load JSON")
	end
	local file = io.open(filename, "r")
	if not file then
		error("could not read '" .. filename .. "'")
	end
	local contents = file:read("*a")
	file:close()
	self._bytecodeHeader = {}
	self._instructions = {}
	if mode == "json" then
		local data = json.decode(contents)
		self._bytecodeHeader = data.header
		self._instructions = data.instructions
		if not self._bytecodeHeader or not self._instructions then
			error("file format not compatible")
		end
	elseif mode == "text" then
		if contents:sub(contents:len()) ~= "\n" then
			contents = contents .. "\n"
		end
		local firstLine, remainder = contents:match("(.-)\n(.+)")
		if hasJSON then
			self._bytecodeHeader = json.decode(firstLine)
		elseif not self.ignoreTextBytecodeHeader then
			print("Warning: no JSON parser loaded, so the interpreter cannot validate if " .. filename .. " is compatible. Place `json.lua` in the same directory as `hollicode.lua` to load JSON or set `hollicode.ignoreTextBytecodeHeader` to `true` to ignore.")
		end
		local currentLine = 0
		for instruction in remainder:gmatch("(.-)\n") do
			currentLine = currentLine + 1
			local left, right = instruction:match("^(%w+)(.*)$")
			if right ~= nil then
				-- skip delimiter & replace escapes
				-- FIXME: escape substitution needs serious improvement. May implement
				-- in compiler, since this is a non-trivial problem for interpreters to
				-- solve, especially given special character escape codes, etc.
				right = right:sub(2):gsub("(\\?)(.)", function(escape, str)
					if escape ~= "\\" then
						return str
					else
						if str == "n" then
							return "\n"
						elseif str == "t" then
							return "\t"
						else
							return str
						end
					end
				end)
			end
			if not instructionExecution[left] then
				print("Warning: unrecognized instruction '" .. left .. "' in " .. filename .. ". Ignoring.")
			else
				table_insert(self._instructions, left and right and {left, right} or left)
			end
		end
	end

	if not supportedBytecodeVersions[self._bytecodeHeader.bytecodeVersion] then
		print("Warning: interpreter may not support file " .. filename .. " as it uses a bytecode version (" .. self._bytecodeHeader.bytecodeVersion .. ") that has not been marked as compatible")
	end
end

function HollicodeInterpreter:push(value)
	if value == nil then
		self:_push(NIL_CONSTANT)
	else
		self:_push(value)
	end
end

-- Proceeds with execution from the current instruction.
function HollicodeInterpreter:go()
	self._yield = false
	while not self._yield do
		self:_executeNextInstruction()
	end
end

-- Selects an option to continue execution from.
function HollicodeInterpreter:goToOption(optionNumber)
	if optionNumber < 0 then
		error("called `gotoOption` with option number < 0")
	elseif optionNumber > #self._options then
		error("option number cannot be > #options")
	else
		self:_pushTraceback()
		self._ip = self._options[optionNumber][1]
		self:_advance(2)
		while #self._options > 0 do
			table_remove(self._options)
		end
	end
end

-- Executes next instruction in the instruction list and continues.
function HollicodeInterpreter:_executeNextInstruction()
	if self._ip > #self._instructions then
		self._yield = true
		return
	elseif self._ip < 1 then
		error("instruction pointer < 0")
	end

	local instruction = self._instructions[self._ip]
	local instructionName, argument
	if type(instruction) == "string" then
		instructionName = instruction
	else
		instructionName = instruction[1]
		argument = instruction[2]
	end
	if instructionExecution[instructionName] then
		instructionExecution[instructionName](self, argument)
	else
		error("unrecognized instruction '" .. instructionName .. "'")
	end
end

-- Emits an echo command.
function HollicodeInterpreter:_emitEcho(what)
	if self.callbacks.echo then
		self.callbacks.echo(self, what)
	end
end

-- Emits an option.
function HollicodeInterpreter:_emitOption(args)
	table_insert(self._options, {self._ip, args})
	if self.callbacks.option then
		self.callbacks.option(self, args)
	end
end

-- Emits a wait command.
function HollicodeInterpreter:_emitWait()
	if self.callbacks.wait then
		self.callbacks.wait(self)
	end
end

-- Peeks at the top value on the stack.
function HollicodeInterpreter:_peek()
	local top = self._stack[#self._stack]
	if top == NIL_CONSTANT then
		return nil
	else
		return top
	end
end

-- Pops the top value off the stack and returns it.
function HollicodeInterpreter:_pop()
	local v = table_remove(self._stack)
	if v == NIL_CONSTANT then
		return nil
	elseif v ~= nil then
		return v
	else
		print("Warning: attempt to pop from empty stack")
		return nil
	end
end

-- Pushes a value onto the top of the stack.
function HollicodeInterpreter:_push(value)
	table_insert(self._stack, value)
end

-- Pushes the current IP to the traceback stack.
function HollicodeInterpreter:_pushTraceback()
	table_insert(self._traceback, self._ip)
end

-- Prints the current stack.
function HollicodeInterpreter:_printStack()
	for i = #self._stack, 1, -1 do
		if self._stack[i] == NIL_CONSTANT then
			print("[nil literal]")
		else
			print(tostring(self._stack[i]))
		end
	end
end

-- Advances the IP by `amount` or 1.
function HollicodeInterpreter:_advance(amount)
	amount = amount or 1
	self._ip = self._ip + amount
	if self._ip > #self._instructions then
		self._yield = true
	elseif self._ip < 0 then
		error("instruction pointer < 0")
	end
end

-- Pops the top off the stack and sets the instruction pointer to it.
function HollicodeInterpreter:_return()
	if #self._traceback > 0 then
		self._ip = table_remove(self._traceback)
		if type(self._ip) ~= "number" then
			error("invalid return")
		else
			if self._ip > #self._instructions then
				self._yield = true
			end
		end
	else
		self._yield = true
	end
end

return HollicodeInterpreter
