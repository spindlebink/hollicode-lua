local hollicode = require("hollicode")

local interpreter = hollicode.new()

interpreter:loadFile("test_code.hcdt")
interpreter:start()
