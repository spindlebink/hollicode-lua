--
-- hollicode.lua
--

local hollicode = {}

local interpreterPrototype = {}
do
  function interpreterPrototype:loadFile(filename)

  end

  function interpreterPrototype:load(bytecodeString)

  end

  -- Resets the interpreter's state.
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
    
  end
end

function hollicode.new()
  local interpreter = {}

  interpreter.ip = 0
  interpreter.traceback = {}
  interpreter.stack = {}
  interpreter.running = false

  setmetatable(interpreter, {__index = interpreterPrototype})
 
  return interpreter
end

return hollicode
