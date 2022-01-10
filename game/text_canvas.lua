-- text_canvas.lua
--
-- Vertically-aligned text stream using rich_text.lua.
--
-- Copyright (c) 2021-2022 Stanaforth (@spindlebink).
--
-- Licensed under the Affero GPL v3.0.

local TextCanvas = {}

local RichText = require("game.rich_text")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

TextCanvas.DEFAULT_FONT = love.graphics.getFont()
TextCanvas.EMPHASIS_FONT = love.graphics.getFont()
TextCanvas.LINE_HEIGHT = 0.95
TextCanvas.PARAGRAPH_PADDING = 10
TextCanvas.DEFAULT_LETTER_SPEED = 0.01
TextCanvas.PERIOD_LETTER_SPEED = 0.35
TextCanvas.COMMA_LETTER_SPEED = 0.15
TextCanvas.PARAGRAPH_WAIT_SPEED = 0.5
TextCanvas.OPTION_PARAGRAPH_WAIT_SPEED = 0.25
TextCanvas.TEXT_DEFAULT_COLOR = {1.0, 1.0, 1.0}
TextCanvas.TEXT_SELECTED_OPTION_COLOR = {0.9, 0.9, 0.9}
TextCanvas.OPTION_INDENT = 36
TextCanvas.OPTION_DEFAULT_COLOR = {1.0, 1.0, 0.92}
TextCanvas.OPTION_HOVERING_COLOR = {0.44, 0.44, 0.42}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Creates a new text canvas.
function TextCanvas:new(width)
	self.__index = self
	local textCanvas = {}
	setmetatable(textCanvas, self)

	textCanvas._wrapWidth = width
	textCanvas._drawOffsetY = 0
	textCanvas._currentTypingText = 1
	textCanvas._currentLetterTimer = 0
	textCanvas._typingParagraphBreak = false
	textCanvas._letterSpeed = textCanvas.DEFAULT_LETTER_SPEED
	textCanvas._lastTypedLetter = ""

	textCanvas._texts = {}
	textCanvas._options = {}

	return textCanvas
end

-- Updates the text canvas. Used to advance the typing effect.
function TextCanvas:update(delta)
	if self._currentTypingText <= #self._texts + #self._options then
		self._currentLetterTimer = self._currentLetterTimer - delta
		if self._currentLetterTimer <= 0 then
			self:_advanceLetter()
			if self._typingParagraphBreak then
				if self._currentTypingText > #self._texts then
					self._letterSpeed = self.OPTION_PARAGRAPH_WAIT_SPEED
				else
					self._letterSpeed = self.PARAGRAPH_WAIT_SPEED
				end
				self._typingParagraphBreak = false
			else
				if self._lastTypedLetter == "." then
					self._letterSpeed = self.PERIOD_LETTER_SPEED
				elseif self._lastTypedLetter == "," then
					self._letterSpeed = self.COMMA_LETTER_SPEED
				else
					self._letterSpeed = self.DEFAULT_LETTER_SPEED
				end
			end
			self._currentLetterTimer = self._letterSpeed
		end
	end
end

-- Draws the text canvas.
function TextCanvas:draw(startIndex, toIndex)
	local offset = 0
	love.graphics.push("all")
	startIndex = startIndex or 1
	toIndex = toIndex or #self._texts + #self._options

	if startIndex < 1 then startIndex = 1 end

	for i = startIndex, toIndex do
		local text = self:getItem(i)
		if text then
			if text._isSelectedOption then
				love.graphics.setColor(self.TEXT_SELECTED_OPTION_COLOR)
			elseif text._isOption then
				if text._isHovering then
					love.graphics.setColor(self.OPTION_HOVERING_COLOR)
				else
					love.graphics.setColor(self.OPTION_DEFAULT_COLOR)
				end
			else
				love.graphics.setColor(self.TEXT_DEFAULT_COLOR)
			end

			love.graphics.translate(text._drawOffsetX, text._drawOffsetY)
			text:draw()
			love.graphics.translate(-text._drawOffsetX, -text._drawOffsetY)
			if i == self._currentTypingText then
				break
			end
		else
			break
		end
	end
	love.graphics.pop()
end

-- Adds a new text object to the canvas.
function TextCanvas:addText(str, asSelectedOption)
	local text = RichText:new()
	local content
	if type(str) == "string" then
		content = {
			{
				text = str,
				font = asSelectedOption and self.EMPHASIS_FONT or self.DEFAULT_FONT
			}
		}
	elseif type(str) == "table" then
		content = str
	end

	text:setLineHeight(self.LINE_HEIGHT)
	text:setText(content)
	text:setWrapWidth(self._wrapWidth - (asSelectedOption and self.OPTION_INDENT or 0))
	text:forceLayout()

	text._isSelectedOption = asSelectedOption
	text._drawOffsetX = asSelectedOption and self.OPTION_INDENT or 0
	text._drawOffsetY = self._drawOffsetY
	self._drawOffsetY = self._drawOffsetY + text.totalHeight + self.PARAGRAPH_PADDING

	text:setVisibleCharacters(0)
	table.insert(self._texts, text)
	return text
end

-- Adds a new option text to the canvas.
function TextCanvas:addOption(str)
	local option = RichText:new()
	local content
	if type(str) == "string" then
		content = {{
			text = str,
			font = self.EMPHASIS_FONT
		}}
	elseif type(str) == "table" then
		content = str
	end

	option:setText(content)
	option:setWrapWidth(self._wrapWidth - self.OPTION_INDENT)
	option:forceLayout()

	option._isOption = true
	option._isHovering = false
	option._drawOffsetX = self.OPTION_INDENT
	option._drawOffsetY = self._drawOffsetY
	self._drawOffsetY = self._drawOffsetY + option.totalHeight + self.PARAGRAPH_PADDING

	option:setVisibleCharacters(0)
	table.insert(self._options, option)
	return option
end

-- Clears options, pushing option `index` as a selected option text.
function TextCanvas:setOptionSelected(index)
	if index < 1 or index > #self._options then
		print("Invalid option index " .. index)
		return
	end

	local option = self._options[index]
	self._drawOffsetY = self._texts[#self._texts]._drawOffsetY + self._texts[#self._texts].totalHeight + self.PARAGRAPH_PADDING
	local newText = self:addText(option._content, true)
	newText:setAllCharactersVisible()

	for i = 1, #self._options do
		self._options[i]:release()
	end
	self._currentTypingText = #self._texts + 1
	self._options = {}
end

-- Returns the text object at index `index`. `TextCanvas` stores separate tables
-- of texts and options, so this method can be used to seamlessly transition
-- between the two---if there are two texts and one option, `getItem(3)` will
-- return the option.
function TextCanvas:getItem(i)
	local t = i <= #self._texts and self._texts or self._options
	return t[i - (i > #self._texts and #self._texts or 0)]
end

-- Returns the total number of items in the text canvas.
function TextCanvas:getItemCount()
	return #self._texts + #self._options
end

-- Returns the total height of the text canvas's contents.
function TextCanvas:getTotalHeight()
	local last = self:getItem(self:getItemCount())
	if not last then
		return 0
	else
		return last._drawOffsetY + last.totalHeight
	end
end

function TextCanvas:getCurrentHeight()
	if self._currentTypingText <= self:getItemCount() and self._currentTypingText > 0 then
		local current = self:getItem(self._currentTypingText)
		return current._drawOffsetY + current.totalHeight
	else
		return self:getTotalHeight()
	end
end

-- Gets the text object overlapping a given Y-coordinate.
function TextCanvas:getItemIndexAtY(y, startingFrom)
	startingFrom = startingFrom or 1
	for i = startingFrom, #self._texts + #self._options do
		local text = self:getItem(i)
		if not text then
			return -1
		elseif y >= text._drawOffsetY and y <= text._drawOffsetY + text.totalHeight then
			return i
		end
	end
	return -1
end

-- Calculates which option is currently under the mouse and selects it.
function TextCanvas:setMouseHoverPosition(x, y)
	if self._currentTypingText <= #self._texts + #self._options then return end

	local setHovering = false
	for i = 1, #self._options do
		local option = self._options[i]
		if not setHovering and y >= option._drawOffsetY and y <= option._drawOffsetY + option.totalHeight then
			setHovering = true
			option._isHovering = true
		else
			option._isHovering = false
		end
	end
end

-- Returns the index of the option currently being hovered.
function TextCanvas:getHoveringOptionIndex()
	for i = 1, #self._options do
		if self._options[i]._isHovering then
			return i
		end
	end
	return -1
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function TextCanvas:_advanceLetter()
	if self._currentTypingText > #self._texts + #self._options or self._currentTypingText < 1 then return end
	local text
	if self._currentTypingText <= #self._texts then
		text = self._texts[self._currentTypingText]
	else
		text = self._options[self._currentTypingText - #self._texts]
	end
	text:setVisibleCharacters(text.visibleCharacters + 1)
	self._lastTypedLetter = text.sourceString:sub(text.visibleCharacters, text.visibleCharacters)
	if text.visibleCharacters == text.sourceString:len() then
		self._currentTypingText = self._currentTypingText + 1
		self._typingParagraphBreak = true
		self._letterSpeed = self.PARAGRAPH_WAIT_SPEED
	end
end

return TextCanvas
