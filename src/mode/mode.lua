--
-- mode.lua
--
-- Schema for states based on love callbacks.
--

require 'state/state'

local mode = state.schema {
	draw = true,
	focus = true,
	keypressed = true,
	keyreleased = true,
	mousepressed = true,
	mousereleased = true,
	update = true,
	textinput = true,
	joystickpressed = true,
	joystickreleased = true,

	joystickaxis = true,
	joystickhat = true,
	gamepadpressed = true,
	gamepadreleased = true,
	gamepadaxis = true,
	joystickadded = true,
	joystickremoved = true,
	mousefocus = true,
	visible = true,
}

return mode