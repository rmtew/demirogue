-- 
-- Vector.lua
--
-- None of the functions in here should assume the vector arguments have the
-- Vector metatable to allow for some flexibility.
-- 

-- require 'AABB'

Vector = {}
Vector.__index = Vector

function Vector.new( tbl )
	-- TODO: this is probably slow but keeping it for the moment to ensure the
	--       change from { x, y } to { x = x, y = y } works.
	assert(type(tbl.x) == 'number')
	assert(type(tbl.y) == 'number')

	local result = {
		x = tbl.x,
		y = tbl.y
	}

	setmetatable(result, Vector)

	return result
end

function Vector.set( self, other )
	self.x = other.x
	self.y = other.y

	return self
end

function Vector.length( self )
	local x, y = self.x, self.y

	return math.sqrt((x * x) + (y * y))
end

function Vector.normal( self )
	local l = Vector.length(self)

	assert(l > 0)

	return Vector.new {
		x = self.x / l,
		y = self.y / l
	}
end

function Vector.normalise( self )
	local l = Vector.length(self)

	assert(l > 0)

	self.x, self.y = self.x / l, self.y / l

	return self
end

function Vector.toLength( self, other )
	local dx = other.x - self.x
	local dy = other.y - self.y

	return math.sqrt((dx * dx) + (dy * dy))
end

function Vector.dot( self, other )
	return (self.x * other.x) + (self.y * other.y)
end

function Vector.to( self, other )
	return Vector.new { x = other.x - self.x, y = other.y - self.y }
end

function Vector.midpoint( self, other )
	local dx = other.x - self.x
	local dy = other.y - self.y

	return Vector.new {
		self.x + (dx * 0.5),
		self.y + (dy * 0.5),
	}
end

function Vector.scale( self, scale )
	self.x = scale * self.x
	self.y = scale * self.y

	return self
end

function Vector.advance( self, target, distance )
	local disp = Vector.to(target, self)
	local dispLength = disp:length()

	assert(dispLength > distance)

	disp:normalise()
	disp:scale(distance)

	self.x = self.x - disp.x
	self.y = self.y - disp.y
end

-- AABB of an array of vectors.
function Vector.aabb( vectors )
	local xmin, xmax = math.huge, -math.huge
	local ymin, ymax = math.huge, -math.huge

	for i = 1, #vectors do
		local vector  = vectors[i]
		xmin = math.min(xmin, vector.x)
		xmax = math.max(xmax, vector.x)
		ymin = math.min(ymin, vector.y)
		ymax = math.max(ymax, vector.y)
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
	return Vector.new { x = -self.y, y = self.x }
end

-- Same as calling perp() three times.
function Vector.antiPerp( self )
	return Vector.new { x = self.y, y = -self.x }
end

function Vector.perpDot( self, other )
	--  vxwy − vywx
	return (self.x * other.y) - (self.y * other.x)
end

function Vector.signedAngle( self, other )
	local perpDot = (self.x * other.y) - (self.y * other.x)
 
	return math.atan2(perpDot, Vector.dot(self, other))
end

function Vector.__tostring( self )
	return string.format("[%f, %f]", self.x, self.y)
end


Vector.tostring = __tostring

local test1 = Vector.new { x = 0, y = 1 }
local test2 = Vector.new { x = 1, y = 0 }
local test3 = Vector.new { x = 0, y = -1 }
local test4 = Vector.new { x = -1, y = 0 }

print(test1, test1, test1:signedAngle(test1))
print(test1, test2, test1:signedAngle(test2))
print(test1, test3, test1:signedAngle(test3))
print(test1, test4, test1:signedAngle(test4))
