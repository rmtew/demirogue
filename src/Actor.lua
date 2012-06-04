require 'Level'

Actor = {}
Actor.__index = Actor

function Actor.new( level, vertex, symbol )
	assert(level.graph.vertices[vertex])
	assert(not vertex.actor)
	assert(type(symbol) == 'string' and #symbol == 1)

	local result = {
		vertex[1],
		vertex[2],
		level = level,
		vertex = vertex,
		symbol = symbol,
	}

	setmetatable(result, Actor)

	vertex.actor = result

	return result
end

function Actor:dirs()
	return self.vertex.dirs
end

function Actor:move( dir )
	local dirs = self.vertex.dirs
	local target = dirs[dir]

	if target and not target.actor then
		self.vertex.actor = nil
		self.vertex = target
		target.actor = self

		return true
	end

	return false
end

function Actor:moveTo( target )
	if target and not target.actor then
		self.vertex.actor = nil
		self.vertex = target
		target.actor = self

		return true
	end

	return false
end



