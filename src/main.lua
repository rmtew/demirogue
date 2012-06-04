require 'gamemode'
require 'glyphmode'

print('_VERSION', _VERSION)

local modes = {
	gamemode,
	glyphmode,
}
local mode = gamemode

function love.load()
	font = love.graphics.newFont('resources/inconsolata.otf', 30)
	love.graphics.setFont(font)
end

function love.update()
	mode.update()
end

function love.draw()
	mode.draw()
end

function love.mousepressed( x, y, button )
	print('love.mousepressed', x, y, button)

	mode.mousepressed(x, y, button)
end

function love.keypressed( key )
	print('love.keypressed', key)

	if key == 'm' then
		mode = glyphmode
	elseif key == 'escape' then
		love.event.push('quit')
	else
		mode.keypressed(key)
	end
end

function love.keyreleased( key )
	print('love.keyreleased', key)

	mode.keyreleased(key)
end
