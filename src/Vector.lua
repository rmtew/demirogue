-- 
-- Vector.lua
--
-- * { x, y } instead of { x = x, y = y } for Love compatibility and
--   performance reasons.
--   NOTE: Actually in LuaJIT builds of Love { x = x, y = y } are faster but
--         I've got so much array based code it would be a bitch to change :^(
-- * All methods should *not* assume that arguments have the Vector metatable
--   assigned so that general 2-elements arrys can use this library.
-- 

-- require 'AABB'

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

function Vector.set( self, other )
	self[1] = other[1]
	self[2] = other[2]

	return self
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

function Vector.scale( self, scale )
	self[1] = scale * self[1]
	self[2] = scale * self[2]

	return self
end

function Vector.advance( self, target, distance )
	local disp = Vector.to(target, self)
	local dispLength = disp:length()

	assert(dispLength > distance)

	disp:normalise()
	disp:scale(distance)

	self[1] = self[1] - disp[1]
	self[2] = self[2] - disp[2]
end

-- AABB of an array of vectors.
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

-- AABB of the keys of a table.
function Vector.keysAABB( tbl )
	-- Empty tables have no AABB.
	assert(next(tbl))

	local xmin, xmax = math.huge, -math.huge
	local ymin, ymax = math.huge, -math.huge

	for vector, _ in pairs(tbl) do
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

function Vector.perp( self )
	return _Vector_new { -self[2], self[1] }
end

-- Same as calling perp() three times.
function Vector.antiPerp( self )
	return _Vector_new { self[2], -self[1] }
end

function Vector.signedAngle( self, other )
	local perpDot = (self[1] * other[2]) - (self[2] * other[1])
 
	return math.atan2(perpDot, Vector.dot(self, other))
end

function Vector.__tostring( self )
	return string.format("[%f, %f]", self[1], self[2])
end


Vector.tostring = __tostring

local test1 = Vector.new { 0, 1 }
local test2 = Vector.new { 1, 0 }
local test3 = Vector.new { 0, -1 }
local test4 = Vector.new { -1, 0 }

print(test1, test1, test1:signedAngle(test1))
print(test1, test2, test1:signedAngle(test2))
print(test1, test3, test1:signedAngle(test3))
print(test1, test4, test1:signedAngle(test4))
