local hollicode = require("hollicode")
local interpreter = hollicode.new()

local love = love
local textList = {}
local optionList = {}

local textOffset = {x = 0, y = 0}

local optionDimColor = {0.55, 0.55, 0.55}
local optionHighlightedColor = {0.85, 0.85, 0.95}

local textCanvas
local textBoxMargin = 12
local textVerticalPadding = 6
local waitingForInput = false
local highlightedOption = 0

local wrapLimit
local pushText, pushOption, layoutText
local defaultFont

local function pushText(text)
	local textObject = love.graphics.newText(defaultFont)
	textObject:addf(text, wrapLimit, "left")
	table.insert(textList, {
		string = text,
		textObject = textObject
	})
end

local function pushOption(optionText)
	local textObject = love.graphics.newText(defaultFont)
	textObject:addf(optionText, wrapLimit - textBoxMargin * 2, "left")
	table.insert(optionList, {
		string = optionText,
		textObject = textObject,
		rect = {x = 0, y = 0, width = 0, height = 0}
	})
end

local function drawText()
	love.graphics.setCanvas(textCanvas)
	love.graphics.push("all")
	love.graphics.clear()
	local increment = textVerticalPadding
	love.graphics.setColor(0.92, 0.92, 0.85)
	for i = 1, #textList do
		local textObject = textList[i].textObject
		love.graphics.draw(textObject, textBoxMargin, increment)
		increment = increment + textObject:getHeight() + textVerticalPadding
	end
	if waitingForInput then
		for i = 1, #optionList do
			local textObject = optionList[i].textObject
			optionList[i].rect.x = textBoxMargin * 2
			optionList[i].rect.y = increment
			optionList[i].rect.width = wrapLimit - textBoxMargin * 2
			optionList[i].rect.height = textObject:getHeight()
			increment = increment + textObject:getHeight() + textVerticalPadding
		end
	end
	if waitingForInput then
		for i = 1, #optionList do
			if highlightedOption == i then
				love.graphics.setColor(optionHighlightedColor)
			else
				love.graphics.setColor(optionDimColor)
			end
			love.graphics.draw(optionList[i].textObject, optionList[i].rect.x, optionList[i].rect.y)
		end
	end
	love.graphics.pop()
	love.graphics.setCanvas()
end

function interpreter:onText(text)
	pushText(text)
end

function interpreter:onOption(optionIndex, optionText)
	pushOption(optionText)
end

function interpreter:onOptionSelected(optionIndex)
	optionList = {}
end

function interpreter:onWait()
	waitingForInput = true
end

function love.load()
	textCanvas = love.graphics.newCanvas(wrapLimit, love.graphics.getHeight())
	defaultFont = love.graphics.newFont("resources/Spectral-Light.ttf", textBoxMargin * 2)
	wrapLimit = defaultFont:getWidth("m") * 35

	interpreter:loadFile("resources/script_compiled.hcdt")
	interpreter:start()
end

function love.update(dt)
	if waitingForInput then
		local mouseX, mouseY = love.mouse.getPosition()
		mouseX, mouseY = mouseX - textOffset.x, mouseY - textOffset.y
		highlightedOption = 0
		for i = 1, #optionList do
			if mouseX >= optionList[i].rect.x and mouseX <= optionList[i].rect.x + optionList[i].rect.width then
				if mouseY >= optionList[i].rect.y and mouseY <= optionList[i].rect.y + optionList[i].rect.height then
					highlightedOption = i
					break
				end
			end
		end
	end
end

function love.draw()
	love.graphics.clear(0.2, 0.225, 0.2)
	love.graphics.setColor(0, 0, 0, 0.5)
	textOffset.x, textOffset.y = love.graphics.getWidth() * 0.5 - wrapLimit * 0.5 - textBoxMargin, 0
	love.graphics.rectangle("fill", textOffset.x, textOffset.y, wrapLimit + textBoxMargin * 2, love.graphics.getHeight())
	love.graphics.setColor(1, 1, 1)
	drawText()
	love.graphics.draw(textCanvas, love.graphics.getWidth() * 0.5 - wrapLimit * 0.5, 0)
end

function love.mousepressed(x, y, button, istouch, presses)
	if waitingForInput and highlightedOption ~= 0 then
		waitingForInput = false
		interpreter:selectOptionAndStart(highlightedOption)
	end
end
