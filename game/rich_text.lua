-- rich_text.lua
--
-- Multi-font, UTF-8 enabled rich text library for LÖVE. 
--
-- Copyright (c) 2021-2022 Stanaforth (@spindlebink).
--
-- Licensed under the Affero GPL v3.0.

local RichText = {}

local utf8 = require("utf8")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

RichText.WRAP_WIDTH = 480

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Creates a new rich text object.
function RichText:new()
	self.__index = self
	local richText = {}
	setmetatable(richText, self)

	richText.sourceString = ""
	richText.wrapWidth = richText.WRAP_WIDTH
	richText.totalHeight = 0
	richText.lineHeight = 1
	richText.visibleCharacters = math.huge

	richText._content = {}
	richText._texts = {}
	richText._needsLayout = false

	return richText
end

-- Draws the rich text object.
function RichText:draw()
	if self._needsLayout then
		self:_layout()
		self._needsLayout = false
	end
	for font, textObject in pairs(self._texts) do
		love.graphics.draw(textObject)
	end
end

-- Sets the text on the rich text.
function RichText:setText(text)
	if type(text) == "string" then
		self.sourceString = text
		self._content = {
			font = love.graphics.getFont(),
			text = text
		}
	elseif type(text) == "table" then
		self._content = text
		self.sourceString = ""
		for i = 1, #text do
			self.sourceString = self.sourceString .. text[i].text
		end
	end
	self._needsLayout = true
end

-- Sets the number of visible characters on the text.
function RichText:setVisibleCharacters(v)
	if v ~= self.visibleCharacters then
		self.visibleCharacters = v
		self._needsLayout = true
	end
end

-- Returns whether all characters are currently being displayed.
function RichText:areAllCharactersVisible()
	return self.visibleCharacters >= utf8.len(self.sourceString)
end

function RichText:setAllCharactersVisible()
	self:setVisibleCharacters(utf8.len(self.sourceString))
end

-- Sets the text's wrap width.
function RichText:setWrapWidth(width)
	if width ~= self.wrapWidth then
		self.wrapWidth = width
		self._needsLayout = true
	end
end

function RichText:setLineHeight(height)
	if height ~= self.lineHeight then
		self.lineHeight = height
		self._needsLayout = true
	end
end

-- Forces a layout computation.
function RichText:forceLayout()
	self:_layout()
end

-- Deletes the rich text object.
function RichText:release()
	for font, textObject in pairs(self._texts) do
		textObject:release()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Lays out the rich text's text.
function RichText:_layout()
	for font, textObject in pairs(self._texts) do
		textObject:clear()
	end

	local lineX, lineY = 0, 0
	local lettersRemaining = math.min(utf8.len(self.sourceString), self.visibleCharacters)
	self.totalHeight = 0

	for i = 1, #self._content do
		local font = self._content[i].font
		local currentPortion = self._content[i].text
		local currentPortionLength = currentPortion:len()
		self._texts[font] = self._texts[font] or love.graphics.newText(font)

		local textObject = self._texts[font]
		local start, current = 1, 1

		while lettersRemaining > 0 and current < currentPortionLength do
			local nextWordBegin = currentPortion:find("[^%s]", current) or currentPortionLength + 1
			local nextSpaceBegin = currentPortion:find("%s", nextWordBegin) or currentPortionLength + 1

			-- the white space characters will never be UTF8, so we don't have to
			-- worry about conversion
			local charsBetween = nextWordBegin - current

			-- add spaces unless we're at the start of a line--`current` here will be
			-- the end of the previous word, and `nextWordBegin` will be the next
			-- word, so the distance between them is all white space
			-- FIXME: we may want to actually measure the substring instead of just
			-- multiplying it by the size of a space--idk if it actually matters
			-- though
			if lineX ~= 0 then
				lineX = lineX + charsBetween * font:getWidth(" ")
				if lineX >= self.wrapWidth then
					lineX = 0
					lineY = lineY + font:getHeight() * self.lineHeight
					self.totalHeight = self.totalHeight + font:getHeight() * self.lineHeight
				end
			end

			if lettersRemaining > charsBetween then
				lettersRemaining = lettersRemaining - charsBetween
			else
				-- short-circuit; we don't actually have to draw the remaining
				-- characters since they're white space here--`charsBetween` is the
				-- space between previous word and this one
				lettersRemaining = 0
				break
			end

			local nextWord = currentPortion:sub(nextWordBegin, nextSpaceBegin - 1)
			local wordWidth = font:getWidth(nextWord)

			if lineX + wordWidth >= self.wrapWidth then
				lineX = 0
				lineY = lineY + font:getHeight() * self.lineHeight
				self.totalHeight = self.totalHeight + font:getHeight() * self.lineHeight
			end

			if lettersRemaining >= utf8.len(nextWord) then
				local toAdd = nextWord
				if self._content[i].color then
					toAdd = {self._content[i].color, toAdd}
				end
				textObject:add(toAdd, lineX, lineY)
				lettersRemaining = lettersRemaining - utf8.len(nextWord)
				lineX = lineX + wordWidth
				current = nextSpaceBegin
			else
				local toAdd = nextWord:sub(utf8.offset(nextWord, 1), utf8.offset(nextWord, lettersRemaining) - 1)
				if self._content[i].color then
					toAdd = {self._content[i].color, toAdd}
				end
				textObject:add(toAdd, lineX, lineY)
				lettersRemaining = 0
			end
		end

		if lettersRemaining == 0 then
			self.totalHeight = self.totalHeight + font:getHeight() * self.lineHeight
		end
	end
end

return RichText
