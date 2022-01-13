local TextCanvas = require("game.text_canvas")
local HollicodeInterpreter = require("lib.hollicode")

local DEFAULT_FONT = love.graphics.newFont("resources/Nunito-Light.ttf", 24)
local EMPHASIS_FONT = love.graphics.newFont("resources/Nunito-LightItalic.ttf", 24)

local interpreter
local textCanvas

local targetScrollBarHeight = love.graphics.getHeight()
local currentScrollBarHeight = targetScrollBarHeight
local scrollBarWidth = 2
local scrollBarHeightMultiplier = 0.25
local scrollBarVisible = false
local scrollBarAlpha = 0
local currentScroll = 0
local targetScroll = 0
local textScreenHeight = 0.75
local atTextBottom = true
local mouseX, mouseY = 0, 0
local minTextIndex = 1
local maxTextIndex = math.huge

local inputEnabled = false
local scrollDirection = 1
local scrollSensitivity = 32
local scrollSmoothRate = 18
local textBoxWidth = 480
local textBoxPadding = 20
local colors = {
	background = {0.15, 0.15, 0.15},
	scrollBar = {0.25, 0.25, 0.25},
	textBox = {0.1, 0.1, 0.1},
	foreground = {0.92, 0.92, 0.92},
	foregroundSelectedOption = {0.46, 0.46, 0.46},
	option = {0.75, 0.75, 0.73},
	optionHovering = {0.42, 0.42, 0.42}
}

-- Loads the interpreter object & Hollicode script file.
local function loadInterpreter()
	interpreter = HollicodeInterpreter:new()
	interpreter:loadFile("script.json")

	-- Provide a `set` method that can be called from Hollicode by adding a new
	-- entry into `variables`.
	interpreter.variables.set = function(name)
		interpreter.variables[name] = true
	end

	-- The `echo` callback is called each time the interpreter wants to push a
	-- line of text to the buffer.
	interpreter.callbacks.echo = function(interpreter, str)
		textCanvas:addText(str)
	end

	-- The `option` callback is called each time the interpreter wants to add an
	-- option to the buffer.
	interpreter.callbacks.option = function(interpreter, params)
		if type(params[1]) == "string" then
			textCanvas:addOption(params[1])
		else
			print("Unknown option arguments")
		end
	end

	-- The `wait` callback is called when the interpreter reaches a `wait`
	-- command, signifying that user input is necessary to proceed.
	interpreter.callbacks.wait = function(interpreter)
		inputEnabled = true
	end
end

-- Loads the text canvas.
local function loadTextCanvas()
	textCanvas = TextCanvas:new(textBoxWidth)
	textCanvas.LINE_HEIGHT = 0.85
	textCanvas.DEFAULT_FONT = DEFAULT_FONT
	textCanvas.EMPHASIS_FONT = EMPHASIS_FONT
	textCanvas.OPTION_DEFAULT_COLOR = colors.option
	textCanvas.OPTION_HOVERING_COLOR = colors.optionHovering
	textCanvas.TEXT_DEFAULT_COLOR = colors.foreground
	textCanvas.TEXT_SELECTED_OPTION_COLOR = colors.foregroundSelectedOption
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function love.load()
	loadInterpreter()
	loadTextCanvas()
	
	interpreter:go()
end

function love.update(delta)
	if atTextBottom then
		scrollBarVisible = false
		if textCanvas:getCurrentHeight() > love.graphics.getHeight() * textScreenHeight then
			targetScroll = -textCanvas:getCurrentHeight() + love.graphics.getHeight() * textScreenHeight-- print("scroll to bottom")
		elseif targetScroll < 0 then
			targetScroll = 0
		end
	else
		scrollBarVisible = true
	end

	local p = currentScroll
	currentScroll = currentScroll + (targetScroll - currentScroll) * (scrollSmoothRate * delta)
	if inputEnabled and math.abs(currentScroll - p) > 0.02 then
		textCanvas:setMouseHoverPosition(mouseX, mouseY - textBoxPadding + currentScroll)
		minTextIndex = textCanvas:getItemIndexAtY(-textBoxPadding - currentScroll)
		if minTextIndex < 1 then
			minTextIndex = 1
		end
		maxTextIndex = textCanvas:getItemIndexAtY(-textBoxPadding - currentScroll + love.graphics.getHeight())
	end

	scrollBarAlpha = scrollBarAlpha + ((scrollBarVisible and 1 or 0) - scrollBarAlpha) * (5 * delta)
	currentScrollBarHeight = currentScrollBarHeight + (targetScrollBarHeight - currentScrollBarHeight) * (scrollSmoothRate * delta)
	textCanvas:update(delta)
end

function love.draw()
	love.graphics.clear(colors.background)
	love.graphics.translate(love.graphics.getWidth() * 0.5 - textBoxWidth * 0.5 - textBoxPadding, 0)
	love.graphics.setColor(colors.textBox)
	love.graphics.rectangle("fill", 0, 0, textBoxWidth + textBoxPadding * 2, love.graphics.getHeight())

	local viewportHeight = love.graphics.getHeight() * textScreenHeight
	local scrollableSpace = textCanvas:getCurrentHeight() - viewportHeight
	if scrollableSpace > 0 then
		targetScrollBarHeight = math.max(love.graphics.getHeight() - scrollableSpace * scrollBarHeightMultiplier, 20)
		local offsettableSpace = viewportHeight - currentScrollBarHeight
		local scrollPercentage = -(atTextBottom and targetScroll or currentScroll) / scrollableSpace
		colors.scrollBar[4] = scrollBarAlpha
		love.graphics.setColor(colors.scrollBar)
		love.graphics.rectangle(
			"fill",
			textBoxWidth + textBoxPadding * 2 - scrollBarWidth * 0.5,
			(love.graphics.getHeight() - targetScrollBarHeight) * scrollPercentage,
			scrollBarWidth,
			currentScrollBarHeight
		)
	end

	love.graphics.translate(textBoxPadding, textBoxPadding + currentScroll)
	textCanvas:draw(
		minTextIndex,
		(maxTextIndex < 1 or maxTextIndex > textCanvas:getItemCount()) and textCanvas:getItemCount() or maxTextIndex
	)
end

function love.mousemoved(x, y)
	if inputEnabled then
		mouseX, mouseY = x, y
		textCanvas:setMouseHoverPosition(x, y - textBoxPadding - currentScroll)
	end
end

function love.mousepressed(x, y, button)
	if inputEnabled then
		if button == 1 then
			textCanvas:setMouseHoverPosition(x, y - textBoxPadding - currentScroll)
			local i = textCanvas:getHoveringOptionIndex()
			if i ~= -1 then
				inputEnabled = false
				textCanvas:setOptionSelected(textCanvas:getHoveringOptionIndex())

				-- To select an option, we go to the option in the interpreter and begin
				-- running again
				interpreter:goToOption(i)
				interpreter:go()
			end
		end
	end
end

function love.wheelmoved(x, y)
	if y > 0 then
		atTextBottom = false
	end
	targetScroll = targetScroll + y * scrollSensitivity * scrollDirection
	if targetScroll > 0 then
		targetScroll = 0
	end
	if targetScroll < -textCanvas:getCurrentHeight() + love.graphics.getHeight() * textScreenHeight then
		atTextBottom = true
	end
end
