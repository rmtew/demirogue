-- 
-- Vector.lua
--
-- * { x, y } instead of { x = x, y = y } for Love compatibility and
--   performance reasons.
-- * All methods should *not* assume that arguments have the Vector metatable
--   assigned so that general 2-elements arrys can use this library.
-- 

Vector = {}
Vector.__index = Vector

function Vector.new( tbl )
	local result = { tbl[1], tbl[2] }

	setmetatable(result, Vector)

	return result
end

function Vector.clone( self )
	local result = { self[1], self[2] }

	setmetatable(result, Vector)

	return result
end

function Vector.length( self )
	local x, y = self[1], self[2]

	return math.sqrt((x * x) + (y * y))
end

local _Vector_length = Vector.length
local _Vector_new = Vector.new

function Vector.normal( self )
	local l = _Vector_length(self)

	assert(l > 0)

	return _Vector_new { self[1] / l, self[2] / l }
end

function Vector.normalise( self )
	local l = _Vector_length(self)

	assert(l > 0)

	self[1], self[2] = self[1] / l, self[2] / l

	return self
end

function Vector.toLength( self, other )
	local dx = other[1] - self[1]
	local dy = other[2] - self[2]

	return math.sqrt((dx * dx) + (dy * dy))
end

function Vector.dot( self, other )
	return (self[1] * other[1]) + (self[2] * other[2])
end

function Vector.to( self, other )
	return _Vector_new { other[1] - self[1], other[2] - self[2] }
end

function Vector.midpoint( self, other )
	local dx = other[1] - self[1]
	local dy = other[2] - self[2]

	return _Vector_new {
		self[1] + (dx * 0.5),
		self[2] + (dy * 0.5),
	}
end

function Vector.scale( self )
	self[1] = scale * self[1]
	self[2] = scale * self[2]

	return self
end

function Vector.aabb( vectors )
	local xmin, xmax = math.huge, -math.huge
	local ymin, ymax = math.huge, -math.huge

	for i = 1, #vectors do
		local vector  = vectors[i]
		xmin = math.min(xmin, vector[1])
		xmax = math.max(xmax, vector[1])
		ymin = math.min(ymin, vector[2])
		ymax = math.max(ymax, vector[2])
	end

	return AABB.new {
		xmin = xmin,
		xmax = xmax,
		ymin = ymin,
		ymax = ymax,
	}
end

function Vector.nearest( vectors1, vectors2 )
	local mindist = math.huge
	local near1, near2 = nil, nil

	for i = 1, #vectors1 do
		for j = 1, #vectors2 do
			local vector1 = vectors1[i]
			local vector2 = vectors2[j]

			local distance = Vector.toLength(vector1, vector2)

			if distance < mindist then
				mindist = distance
				near1, near2 = vector1, vector2
			end
		end
	end

	return mindist, near1, near2
end


