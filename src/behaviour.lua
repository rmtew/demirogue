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
-- node.reset( self:table, level, actor )
--     
--
-- - PERFORM, returns a cost and an action (well the result of an action)
-- - ADVANCE, returns nothing
-- - ABORT, returns nothing
--

require 'action'

behaviour = {
	Result = {
		PERFORM = 'PERFORM',
		ADVANCE = 'ADVANCE',
		ABORT = 'ABORT',
	},
	nodes = {},
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

	if node.oneshot then
		local node_new = node.new
		local node_tick = node.tick
		local node_reset = node.reset

		node.new =
			function ( params )
				local result = node_new(params)
				result.performed = params.performed or false
				return result
			end

		node.tick =
			function ( self, level, actor )
				if self.performed then
					self:reset(level, actor)

					return ADVANCE
				else
					local result, cost, plan = node_tick(self, level, actor)

					if result == PERFORM then
						self.performed = true
						return result, cost, plan
					end

					return result
				end
			end

		node.reset =
			function ( self, level, actor )
				self.performed = false
				node_reset(self, level, actor)
			end
	end

	node.__index = node
	
	nodes[node.tag] = node
end

-- Sequence
--  - tick() subnodes in order.
--  - If a subnode aborts or we advance passed the end, start again from the
--    beginning.
--
-- params = { tag = 'Sequence', <subnode1>, <subnode2>, ..., <subnodeN> }
_node {
	tag = 'Sequence',
	new =
		function ( params )
			local result = {
				subnodes = _behaviour_new_array(params),
				index = params.index or 1,
				performer = nil,
			}

			return result
		end,
	tick = 
		function ( self, level, actor )
			local subnodes = self.subnodes

			for index = self.index, #subnodes do
				local subnode = subnodes[index]
				local result, cost, plan = subnode:tick(level, actor)

				if result == PERFORM then
					self.performer = index
					self.index = index
					return result, cost, plan
				elseif result == ABORT then
					self.performer = nil
					self.index = 1
					return ABORT
				end

				self.performer = nil
			end

			self.index = 1

			return ADVANCE
		end,
	reset =
		function ( self, level, actor )
			local performer = self.performer

			if performer then
				self.subnodes[performer]:reset()
				self.performer = nil
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
_node {
	tag = 'Priority',
	new =
		function ( params )
			local result = {
				subnodes = _behaviour_new_array(params),
				index = params.index or 1,
				performer = nil,
			}

			return result
		end,
	tick = 
		function ( self, level, actor )
			local subnodes = self.subnodes

			local finalResult = nil

			for index = self.index, #subnodes do
				local subnode = subnodes[index]
				local result, cost, plan = subnode:tick(level, actor)

				if result == PERFORM then
					self.performer = index
					self.index = index
					return result, cost, plan
				end

				finalResult = result
				self.performer = nil
			end

			assert(Result[finalResult])

			self.index = 1

			return finalResult
		end,
	reset =
		function ( self, level, actor )
			local performer = self.performer

			if performer then
				self.subnodes[performer]:reset()
				self.performer = nil
			end
		end,
}

_node {
	tag = 'Guarded',
	new =
		function ( params )
			local result = {
				subnodes = _behaviour_new_array(params),
				performer = nil,
			}

			return result
		end,
	tick = 
		function ( self, level, actor )
			local subnodes = self.subnodes

			for index = self.performer or 1, #subnodes do
				local subnode = subnodes[index]
				local result, cost, plan = subnode:tick(level, actor)

				if result == PERFORM then
					self.performer = index
					return result, cost, plan
				elseif result == ABORT then
					if self.performer then
						subnodes[self.performer]:reset(level, actor)
						self.performer = nil
					end
					
					return ABORT
				end

				self.performer = nil
			end

			return ADVANCE
		end,
	reset =
		function ( self, level, actor )
			local performer = self.performer

			if performer then
				self.subnodes[performer]:reset()
				self.performer = nil
			end
		end,
}

_node {
	tag = 'Loop',
	new =
		function ( params )
			local result = {
				subnodes = _behaviour_new_array(params),
				index = params.index or 1,
				performer = nil,
			}

			return result
		end,
	tick = 
		function ( self, level, actor )
			local subnodes = self.subnodes

			while true do
				local subnode = subnodes[self.index]
				local result, cost, plan = subnode:tick(level, actor)

				if result == PERFORM then
					self.performer = index
					return result, cost, plan
				elseif result == ABORT then
					self.performer = nil
					self.index = 1
					
					return ABORT
				end

				self.performer = nil

				self.index = (self.index < #subnodes) and self.index + 1 or 1
			end
		end,
	reset =
		function ( self, level, actor )
			local performer = self.performer

			if performer then
				self.subnodes[performer]:reset()
				self.performer = nil
			end
		end,
}

_node {
	tag = 'Advance',
	new =
		function ( params )
			return {}
		end,
	tick =
		function ( self, level, actor )
			return ADVANCE
		end,
	reset =
		function ( self )
		end,
}

_node {
	tag = 'Abort',
	new =
		function ( params )
			return {}
		end,
	tick =
		function ( self, level, actor )
			return ABORT
		end,
	reset =
		function ( self )
		end,
}

_node {
	tag = 'Search',
	oneshot = true,
	new =
		function ( params )
			return {}
		end,
	tick =
		function ( self, level, actor )
			return PERFORM, action.search(level, actor)
		end,
	reset =
		function ( self, level, actor )
		end,
}

_node {
	tag = 'Bounce',
	oneshot = true,
	new =
		function ( params )
			return {}
		end,
	tick =
		function ( self, level, actor )
			local height = 30
			local period = 0.75
			local anim =
				function ( time )
					local bias = (time % period) / period
					local t = 2 * (bias - 0.5)
					local y = -height * (1 - (t*t))

					return 0, y
				end

			actor.anim = anim

			return PERFORM, 5, nil
		end,
	reset =
		function ( self, level, actor )
			actor.anim = nil
		end,
}

_node {
	tag = 'Wander',
	oneshot = true,
	new =
		function ( params )
			return {}
		end,
	tick =
		function ( self, level, actor )
			local candidates = {}

			for vertex, _ in pairs(level.graph.vertices[actor.vertex]) do
				if not vertex.actor then
					candidates[vertex] = true
				end
			end

			if table.count(candidates) == 0 then
				return ABORT
			else
				local target = table.random(candidates)

				return PERFORM, action.move(level, actor, target)
			end
		end,
	reset =
		function ( self, level, actor )
		end,
}

_node {
	tag = 'Target',
	new =
		function ( params )
			-- TODO: isPosInt() misc function.
			assert(type(params.range) == 'number' and math.floor(params.range) == params.range and params.range > 0)
			assert(type(params.symbol) == 'string' and #params.symbol > 0)

			return {
				range = params.range,
				symbol = params.symbol,
			}
		end,
	tick =
		function ( self, level, actor )
			local map = level:distanceMap(actor.vertex, self.range)

			for vertex, distance in pairs(map) do
				if distance == self.range and vertex.actor and vertex.actor.symbol == self.symbol then
					actor.target = vertex

					return ADVANCE
				end
			end

			return ABORT
		end,
	reset =
		function ( self, level, actor )
			actor.target = nil
		end,
}

_node {
	tag = 'Melee',
	oneshot = true,
	new =
		function ( params )
			return {}
		end,
	tick =
		function ( self, level, actor )
			if actor.target and actor.target.actor then
				return PERFORM, action.melee(level, actor, actor.target.actor)
			end

			return ABORT
		end,
	reset =
		function ( self, level, actor )
			actor.target = nil
		end,
}

_node {
	tag = 'Leap',
	oneshot = true,
	new =
		function ( params )
			return {}
		end,
	tick =
		function ( self, level, actor )
			if actor.target then
				return PERFORM, action.leap(level, actor, actor.target)
			end

			return ABORT
		end,
	reset =
		function ( self, level, actor )
			actor.target = nil
		end,
}