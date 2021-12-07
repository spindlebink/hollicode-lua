--
-- hollicode.lua
--

local hollicode = {}

local string_match = string.match
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove
local tonumber = tonumber
local type = type

local NIL_CONSTANT = {}

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

	-- User-facing version of `push`.
	function interpreterPrototype:push(var)
		self:_push(var)
	end

	--
	-- VM methods
	--
	function interpreterPrototype:_emitRequest(requestType, name)
		self:_push(function(a, b, c)
			print(a, b, c)
		end)
	end

	function interpreterPrototype:_advance(distance)
		local distance = distance or 1
		self.ip = self.ip + distance
	end

	function interpreterPrototype:_push(value)
		table_insert(self.stack, value)
	end

	function interpreterPrototype:_pop()
		local result = table_remove(self.stack)
		if result == NIL_CONSTANT then
			return nil
		else
			return result
		end
	end

	function interpreterPrototype:_peek()
		return self.stack[#self.stack]
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
	operations["RET"] = function(self)
		self:_return()
	end

	operations["POP"] = function(self)
		self:_advance()
		self:_pop()
	end

	operations["JMP"] = function(self, distance)
		local distance = tonumber(distance)
		self:_advance(distance)
	end

	operations["FJMP"] = function(self, distance)
		if not self:_peek() then
			local distance = tonumber(distance)
			self:_advance(distance)
		end
	end

	operations["GOTO"] = function(self, ip)
		local ip = tonumber(ip)
		self:_pushIP()
		-- Have to increment by one because Lua uses 1-indexed tables
		self.ip = ip + 1
	end

	operations["NIL"] = function(self)
		self:_advance()
		-- We have to push a unique table because Lua doesn't take kindly to pushing
		-- an actual `nil` to a table.
		self:_push(NIL_CONSTANT)
	end

	operations["BOOL"] = function(self, bool)
		self:_advance()
		self:_push(bool == "true" and true or false)
	end

	operations["NUM"] = function(self, num)
		self:_advance()
		self:_push(tonumber(num))
	end

	operations["STR"] = function(self, str)
		self:_advance()
		self:_push(str)
	end

	operations["GETV"] = function(self, variableName)
		self:_advance()
		local originalStackSize = #self.stack
		if type(self.variables) == "table" then
			local v = self.variables[variableName]
			if v then
				self:_push(v)
			end
		elseif type(self.variables) == "function" then
			local v = self.variables(variableName)
			if v then
				self:_push(v)
			end
		end
		if #self.stack == originalStackSize then
			error("requested variable '" .. variableName .. "' but got nothing")
		end
	end

	operations["GETF"] = function(self, functionName)
		self:_advance()
		local originalStackSize = #self.stack
		if type(self.functions) == "table" then
			local f = self.functions[functionName]
			if f then
				self:_push(f)
			end
		elseif type(self.functions) == "function" then
			local f = self.functions(functionName)
			if f then
				self:_push(f)
			end
		end
		if #self.stack == originalStackSize then
			error("requested function '" .. functionName .. "' but got nothing")
		end
	end

	operations["NOT"] = function(self)
		self:_advance()
		self.stack[#self.stack] = not self.stack[#self.stack]
	end

	operations["NEG"] = function(self)
		self:_advance()
		self.stack[#self.stack] = -self.stack[#self.stack]
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

	operations["ADD"] = function(self)
		self:_advance()
		self:_push(self:_pop() + self:_pop())
	end

	operations["SUB"] = function(self)
		self:_advance()
		self:_push(self:_pop() - self:_pop())
	end

	operations["MULT"] = function(self)
		self:_advance()
		self:_push(self:_pop() * self:_pop())
	end

	operations["DIV"] = function(self)
		self:_advance()
		self:_push(self:_pop() / self:_pop())
	end

	operations["ECHO"] = function(self)
		self:_advance()
		local str = self:_pop()
		print(str)
	end

	operations["OPT"] = function(self)
		self:_advance()
		print("SHOW OPTION")
		self:_pop()
	end

	operations["WAIT"] = function(self)
		self:_advance()
		print("WAIT")
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

	interpreter.functions = {}
	interpreter.variables = {}

	setmetatable(interpreter, {__index = interpreterPrototype})
	setmetatable(interpreter.operations, {__index = operations})

	return interpreter
end

return hollicode
