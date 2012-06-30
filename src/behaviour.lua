--
-- behaviour.lua
--
-- Provides a framework for AI based on Behaviour Trees but adapted for a turn
-- based system. Behaviours are built on top of actions (see action.lua).
--
-- A behaviour is made with a tree of nodes. All nodes support the following
-- interface:
-- 
-- node.new( params:table ) : table
--     The params argument is a table of values used to define the node. The
--     only required element is a tag that defines which type of node the
--     params are for. The return value of the new() function should be a table
--     representing the state of the node.
--
-- node.tick( self:table, level, actor ) : Result, cost:integer? action?
--     The self argument is the table returned by new(). The level argument is
--     the current level and actor is what is being controlled by the
--     behaviour.
--     Result is one of the values in behaviour.Result and the cost and action
--     are only returned if the Result is PERFORM.
--
-- node.reset( self:table )
--     
--

-- - So how to handle conditionals?
--   - They return ADVANCE or ABORT depending on whether their conditions are met.
--   - They don't return actions though.
--
-- - PERFORM, returns a cost and an action (well the result of an action)
-- - ADVANCE, returns nothing
-- - ABORT, returns nothing
--
-- - Need better names, e.g. PERFORM, CONTINUE, ABORT

Sequence {
	IfPlayer { withinRange = 2 },
	Bounce {},
	Leap {}, -- How does this know where to leap? Need a target.
}


behaviour = {
	Result = {
		PERFORM = 'PERFORM',
		ADVANCE = 'ADVANCE',
		ABORT = 'ABORT',
	}
	nodes = {}
}

local Result = behaviour.Result

local PERFORM = Result.PERFORM
local ADVANCE = Result.ADVANCE
local ABORT = Result.ABORT

local nodes = behaviour.nodes


function behaviour.new( params )
	local node = nodes[params.tag]
	local result = node.new(params)

	setmetatable(result, node)

	return result
end

local _behaviour_new = behaviour.new

local function _behaviour_new_array( array )
	local result = {}

	for index, params in ipairs(array) do
		result[index] = _behaviour_new(params)
	end

	return result
end

local function _node( node )
	assert(type(node) == 'table')
	assert(type(node.tag) == 'string' and #node.tag > 0 and not nodes[node.tag])
	assert(type(node.new) == 'function')
	assert(type(node.tick) == 'function')
	assert(type(node.reset) == 'function')
	
	nodes[node.tag] = node
end

-- Sequence
--  - tick() subnodes in order.
--  - If a subnode aborts or we advance passed the end, start again from the
--    beginning.
--
-- params = { tag = 'Sequence', <subnode1>, <subnode2>, ..., <subnodeN> }
nodes.Sequence = _node {
	new =
		function ( params )
			local result = {
				subnodes = _behaviour_new_array(params),
				index = params.index or 1
			}

			return result
		end,
	tick = 
		function ( self, level, actor )
			local subnodes = self.subnodes

			while self.index <= #subnodes do
				local node = self.subnodes[self.index]
				local result, cost, plan = self.subnodes[i](node, level, actor)

				if result ~= ADVANCE then
					return result, cost, plan
				end

				self.index = self.index + 1
			end

			return ADVANCE
		end,
	exit =
		function ( self, result )
			if result == ABORT or self.index == #self.subnodes then
				self.index = 1
			end
		end,
}

-- Priority
--  - tick()s all subnodes in-order until one PERFORMs or ADVANCEs.
--  - ABORTs if no subnodes
--  - If a subnode aborts or we advance passed the end, start again from the
--    beginning.
--
-- params = { tag = 'Priority', <subnode1>, <subnode2>, ..., <subnodeN> }
nodes.Priority = _Stateful {
	new =
		function ( params )
			assert(params.tag == 'Priority')

			local subnodes = {}

			for index, params in ipairs(params) do
				subnodes[index] = _behaviour_new(params)
			end

			local result = {
				subnodes = subnodes,
				index = params.index or 1
			}

			return result
		end,
	tick = 
		function ( self, level, actor )
			local subnodes = self.subnodes

			while self.index <= #subnodes do
				local node = self.subnodes[self.index]
				local result, cost, plan = self.subnodes[i](node, level, actor)

				if result ~= ABORT then
					return result, cost, plan
				end

				self.index = self.index + 1
			end

			return ADVANCE
		end,
	exit =
		function ( self, result )
			self.index = 1
		end,
}

