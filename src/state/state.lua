--
-- state.lua
--
-- A stack based state machine library intended for high-level control of
-- program flow in a love game. As such all states have default handlers
-- for the top-level love callbacks:
--
--   draw()
--   focus( isfocussed )
--   keypressed( key, isrepeat )
--   keyreleased( key )
--   mousepressed( x, y, button )
--   mousereleased( x, y, button )
--   quit()
--   update( dt )
--   textinput( unicode )
--   joystickpressed( joystick, button )
--   joystickreleased( joystick, button )
--
-- There is no support for run(), errhand() or quit().
--
-- Potential Love 0.9.0 callbacks to add support for.
-- 
--   joystickaxis(j,a,v)
--   joystickhat(j,h,v)
--   gamepadpressed(j,b)
--   gamepadreleased(j,b)
--   gamepadaxis(j,a,v)
--   joystickadded(j)
--   joystickremoved(j)
--   mousefocus(f)
--   visible(v)
--
-- There are two extra methods you can
-- enter( arg )
-- exit()
-- become(name, arg)
-- push(name, arg)
-- pop()

-- 

--[[

local foo = state.new(<name>)

funcion foo:enter( args )
	-- c'tor like logic here.
end

function foo:exit()
	-- d'tor like logic here
end

function foo:draw()
	-- ...

	-- draw() not called on previous states.
	return 'break'
end

function foo:update( dt )
	-- ...
end

function foo:keypressed( key, isrepeat )
	if key == 'delete' then
		return self:push('Dialog', {
			'Delete' = function () ... end,
			"Don't Delete" = function () .. end,
		})
	elseif key == 'return' then
		return self:become('NextState', foo)
	end
end

local bar = state.machine(<init-state>, <args>)

--]]

state = {
	new = nil,
	machine = nil,
}

local function _process( stack, i, response )
	if response == nil or response == 'break' then
		return response
	end

	assert(type(response) == 'function', "response should be nil, 'break' or a function")

	return response(stack, i)
end

-- { [name] = statemt }
local _statemts = {}

local _statemtmt = {
	__index = nil,

	enter = function ( self ) end,
	exit = function ( self ) end,
	become =
		function ( self, name, param )
			local statemt = _statemts[name]
			assert(statemt, 'invalid state')

			return
				function ( stack, i )
					assert(rawequal(stack[i], self), 'become called on incorrect state')

					local instance = setmetatable({}, statemt)
					local response = stack[i]:exit()
					assert(response == nil, "state exit shouldn't return anything")
					stack[i] = instance

					return _process(stack, i, instance:enter(param))
				end
		end,
	push =
		function ( self, name, param )
			local statemt = _statemts[name]
			assert(statemt, 'invalid state')

			return
				function ( stack, i )
					assert(rawequal(stack[i], self), 'push called on incorrect state')

					local instance = setmetatable({}, statemt)
					local top = #stack+1
					stack[top] = instance
					return _process(stack, top, instance:enter(param)) 
				end
		end,
	pop = 
		function ( self )
			return
				function ( stack, i )
					assert(rawequal(stack[i], self), 'state pop called on wrong state')
					local response = stack[i]:exit()
					assert(response == nil, "state exit shouldn't return anything")
					table.remove(stack, i)

					assert(#stack > 0, 'state machine is empty')
				end
		end,

	draw = function( self ) end,
	focus = function( self, bool ) end,
	keypressed = function( self, key, isrepeat ) end,
	keyreleased = function( self, key ) end,
	mousepressed = function( self, x, y, button ) end,
	mousereleased = function( self, x, y, button ) end,
	quit = function( self ) end,
	update = function( self, dt ) end,
	textinput = function( self, unicode ) end,
	joystickpressed = function( self, joystick, button ) end,
	joystickreleased = function( self, joystick, button ) end,
}
_statemtmt.__index = _statemtmt

function state.new( name )
	assert(_statemts[name] == nil, 'attempted state redefinition.')
	
	local result = setmetatable({ _name = name, __index = nil }, _statemtmt)
	result.__index = result
	_statemts[name] = result

	return result
end

local _events = {
	draw = true,
	focus = true,
	keypressed = true,
	keyreleased = true,
	mousepressed = true,
	mousereleased = true,
	quit = true,
	update = true,
	textinput = true,
	joystickpressed = true,
	joystickreleased = true,
}

local function _handler( event )
	assert(_events[event], 'invalid state event')
	return
		function ( self, ... )
			local stack = self.stack
			for i = #stack, 1, -1 do
				local instance = stack[i]
				
				if _process(stack, i, instance[event](instance, ...)) == 'break' then
					break
				end
			end
		end
end

local _machinemt = {
	__index = nil,

	-- TODO: draw maybe a special case and need to access parent state handlers.
	draw = _handler('draw'),
	focus = _handler('focus'),
	keypressed = _handler('keypressed'),
	keyreleased = _handler('keyreleased'),
	mousepressed = _handler('mousepressed'),
	mousereleased = _handler('mousereleased'),
	quit = _handler('quit'),
	update = _handler('update'),
	textinput = _handler('textinput'),
	joystickpressed = _handler('joystickpressed'),
	joystickreleased = _handler('joystickreleased'),
}
_machinemt.__index = _machinemt

function state.machine( name, param )
	local result = {
		stack = {},
	}

	setmetatable(result, _machinemt)

	local statemt = _statemts[name]
	assert(statemt, 'invalid start state')

	local instance = setmetatable({}, statemt)
	result.stack[1] = instance

	print('#stack', #result.stack)

	_process(result.stack, 1, instance:enter(param))

	return result
end


local test1 = state.new('test1')
function test1:enter(arg)
	print(arg, arg)
	return self:become('test2', 'bar')
end

function test1:exit()
	print('test1:exit()')
end

local test2 = state.new('test2')
function test2:enter(arg)
	print('test2', arg)
end

function test2:draw()
	print('test2:draw')
end

function test2:update(dt)
	print('test2:update', dt)
	return self:push('test3', 'baz')
end

local test3 = state.new('test3')
function test3:enter(arg)
	print('test3', arg)
end
function test3:exit(arg)
	print('test3:exit()')
end
function test3:update(dt)
	print('test3:update', dt)
	return self:pop()
end
local testMachine = state.machine('test1', 'foo')

function printf( ... ) print(string.format(...)) end

printf('#stack %d', #testMachine.stack)
testMachine:update(1/30)
printf('#stack %d', #testMachine.stack)
testMachine:update(1/30)
printf('#stack %d', #testMachine.stack)
testMachine:draw()
