--
-- hollicode.lua
--

local hollicode = {}

local string_match = string.match
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove

-- Interpreter methods
local interpreterPrototype = {}
do
	--
	-- User-facing methods
	--

	-- Loads bytecode from a file.
	function interpreterPrototype:loadFile(filename)
		local inputFile = io.open(filename, "r")
		if not inputFile then
			error("could not open file '" .. filename .. "'.")
		end
		local bytecodeString = inputFile:read("*a")
		if not bytecodeString then
			inputFile:close()
			error("could not read file '" .. filename .. "'.")
		end
		inputFile:close()
		self:load(bytecodeString)
	end

	-- Loads bytecode from a string.
	function interpreterPrototype:load(bytecodeString)
		if string.sub(bytecodeString, string.len(bytecodeString)) ~= "\n" then
			bytecodeString = bytecodeString .. "\n"
		end
		for instruction in string.gmatch(bytecodeString, "(.-)\n") do
			table_insert(self.instructions, instruction)
		end
	end

	-- Resets the interpreter's state. Does not reset any loaded bytecode.
	function interpreterPrototype:reset()
		self.ip = 1
		self.traceback = {}
		self.stack = {}
		self.running = false
	end

	-- Restarts the interpreter from 0 with a fresh state.
	function interpreterPrototype:restart()
		self:reset()
		self:start()
	end

	-- Starts the interpreter from the current instruction.
	function interpreterPrototype:start()
		self.running = true
		while self.running do
			self:executeCurrentInstruction()
		end
	end

	-- Executes the current instruction and advances IP accordingly.
	function interpreterPrototype:executeCurrentInstruction()
		if self.ip > #self.instructions then
			self.running = false
			return
		elseif self.ip < 1 then
			error("instruction pointer < 0")
		end

		local left, right = string_match(self.instructions[self.ip], "^(%w+)(.*)$")
		if right ~= nil then
			right = string_sub(right, 2)
		end
		local operation = self.operations[left]
		if operation then
			operation(self, right)
		else
			error("unrecognized bytecode command " .. left)
		end
	end

	--
	-- VM methods
	--
	function interpreterPrototype:_emitRequest(requestType, name)
		self:_push(function(a, b, c)
			print(a, b, c)
		end)
	end

	function interpreterPrototype:_advance()
		self.ip = self.ip + 1
	end

	function interpreterPrototype:_push(value)
		table_insert(self.stack, value)
	end

	function interpreterPrototype:_pop()
		return table_remove(self.stack)
	end

	function interpreterPrototype:_pushIP()
		table_insert(self.traceback, self.ip)
	end

	function interpreterPrototype:_return()
		if #self.traceback > 0 then
			self.ip = table_remove(self.traceback) + 1
		else
			print("Warning: attempting to return with no traceback. Ignoring.")
		end
	end
end

-- 
local operations = {}
do
	operations["STR"] = function(self, str)
		self:_advance()
		self:_push(str)
	end

	operations["ECHO"] = function(self)
		self:_advance()
		local str = self:_pop()
		print(str)
	end

	operations["FUNC"] = function(self, functionName)
		self:_advance()
		local originalStackSize = #self.stack
		self:_emitRequest("function", functionName)
		if #self.stack == originalStackSize then
			error("requested a function '" .. functionName .. "' but got nothing")
		end
	end

	operations["CALL"] = function(self, numArguments)
		self:_advance()
		local func = self:_pop()
		local arguments = {}
		for i = 1, tonumber(numArguments) do
			table_insert(arguments, self:_pop())
		end
		func(unpack(arguments))
	end
end

-- Creates a new interpreter.
function hollicode.new()
	local interpreter = {}

	interpreter.ip = 1
	interpreter.instructions = {}
	interpreter.operations = {}
	interpreter.traceback = {}
	interpreter.stack = {}
	interpreter.running = false

	setmetatable(interpreter, {__index = interpreterPrototype})
	setmetatable(interpreter.operations, {__index = operations})

	return interpreter
end

return hollicode
