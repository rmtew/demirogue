require 'Vector'
require 'glyph'

glyphmode = {}

local function _round( value )
	return math.floor(value + 0.5)
end

local current = glyph.new()
local rect = {
	x = 100,
	y = 100,
	width = 300,
	height = 300,
}
local centre = Vector.new {
	rect.x + _round(rect.width * 0.5),
	rect.y + _round(rect.height * 0.5),
}

local mini = {
	x = rect.x + rect.width + 100,
	y = rect.y,
	width = 50,
	height = 50,
}
local minicentre = Vector.new {
	mini.x + _round(mini.width * 0.5),
	mini.y + _round(mini.height * 0.5),
}

local linemode = false
local line = {}
local lineindex = nil
local undos = {}

local function _within( rect, x, y )
	local inx = rect.x <= x and x < rect.x + rect.width
	local iny = rect.y <= y and y < rect.y + rect.height

	return inx and iny
end

function glyphmode.update()
end

function glyphmode.draw()
	local fg = { r = 255, g = 255, b = 0, a = 255 }
	local bg = { r = 0, g = 0, b = 255, a = 255 }
	local fgwidth = 4
	local bgwidth = 6
	love.graphics.push()
	love.graphics.translate(centre[1], centre[1])
	current:draw(fg, bg, fgwidth, bgwidth)
	love.graphics.pop()

	love.graphics.push()
	love.graphics.translate(minicentre[1], minicentre[2])
	love.graphics.scale(mini.width / rect.width, mini.height / rect.height)
	current:draw(fg, bg, fgwidth * 6, bgwidth * 6)
	love.graphics.pop()

	love.graphics.setLineWidth(1)

	love.graphics.rectangle('line', rect.x, rect.y, rect.width, rect.height)
	love.graphics.rectangle('line', mini.x, mini.y, mini.width, mini.height)

	local x, y = love.mouse.getPosition()
	
	if _within(rect, x, y) then
		love.graphics.setLineWidth(1)

		love.graphics.line(x-5, y-5, x+5, y+5)
		love.graphics.line(x+5, y-5, x-5, y+5)
	end

	love.graphics.print(string.format('linemode:%s', tostring(linemode)), 10, 10)
end

local _mousepressed = nil

function glyphmode.mousepressed( x, y, button )
	if not _within(rect, x, y) then
		return
	end

	local point = centre:to(Vector.new { x = x, y = y })

	if not linemode then
		local index = current:addPoint(point)

		local undo = 
			function ()
				current:removePoint(index)
			end

		undos[#undos+1] = undo
	else
		local prev = {}

		for i, point in ipairs(line) do
			prev[i] = Vector.new(point)
		end

		line[#line+1] = point

		if #line > 1 then
			local index = current:addLine(line, lineindex)
			lineindex = index

			local undo =
				function ()
					current:removeLine(index)

					if #prev > 1 then
						current:addLine(prev, index)
					end
				end

			undos[#undos+1] = undo
		end
	end
end

function glyphmode.keypressed( key )
	if key == 'delete' then
		current = glyph.new()
		line = {}
		lineindex = nil
		undos = {}
	elseif key == 'u' then
		local undo = undos[#undos]

		if undo then
			undo()
			undos[#undos] = nil
		end
	elseif key == 'l' then
		linemode = not linemode

		if not linemode then
			line = {}
			lineindex = nil
		end
	elseif key == 'd' then
		current:dump()
	end
end

function glyphmode.keyreleased( key )
end
