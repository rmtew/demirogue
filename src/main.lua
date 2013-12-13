-- All other lua files assume this is required before they are.
require 'prelude'

require 'themes'

local schema = require 'lib/mode' {}

-- require 'gamemode'
require 'voronoimode'
require 'graphmode'
-- require 'glyphmode'

print('_VERSION', _VERSION)

--
-- Love callbacks
--
-- love.draw()             Callback function used to draw on the screen every
--                         frame.
-- love.focus(bool)        Callback function triggered when window receives or
--                         loses focus.
-- love.joystickpressed()  Called when a joystick button is pressed.
-- love.joystickreleased() Called when a joystick button is released.
-- love.keypressed()       Callback function triggered when a key is pressed.
-- love.keyreleased()      Callback function triggered when a key is released.
-- love.load()             This function is called exactly once at the beginning of the game.
-- love.mousepressed()     Callback function triggered when a mouse button is pressed.
-- love.mousereleased()    Callback function triggered when a mouse button is released.
-- love.quit()             Callback function triggered when the game is closed.
-- love.run()              The main function, containing the main loop. A sensible default is used when left out.
-- love.update()           Callback function used to update the state of the game every frame.

local modes = {
	gamemode,
	glyphmode,
}
local mode = voronoimode

function love.load()
	gFont30 = love.graphics.newFont('resource/inconsolata.otf', 30)
	gFont15 = love.graphics.newFont('resource/inconsolata.otf', 15)
	love.graphics.setFont(gFont30)

	themes.load()
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

function love.mousereleased( x, y, button )
	print('love.mousereleased', x, y, button)

	mode.mousereleased(x, y, button)
end

function love.keypressed( key, isrepeat )
	printf('love.keypressed %s %s', key, tostring(isrepeat))

	if key == 'escape' then
		love.event.push('quit')
	elseif key == '0' then
		if mode == voronoimode then
			mode = graphmode
		elseif mode == graphmode then
			mode = voronoimode
		end
	else
		mode.keypressed(key)
	end
end

function love.keyreleased( key, unicode )
	print('love.keyreleased', key)

	mode.keyreleased(key)
end
