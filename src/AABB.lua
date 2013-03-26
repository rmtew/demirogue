require 'Vector'

AABB = {}
AABB.__index = AABB

function AABB.new( tbl )
	local result = {
		xmin = tbl.xmin,
		ymin = tbl.ymin,
		xmax = tbl.xmax,
		ymax = tbl.ymax,
	}

	assertf(result.xmin <= result.xmax, '%.2f <= %.2f failed', result.xmin, result.xmax)
	assertf(result.ymin <= result.ymax, '%.2f <= %.2f failed', result.ymin, result.ymax)

	setmetatable(result, AABB)

	return result
end

function AABB:width()
	return self.xmax - self.xmin
end

function AABB:height()
	return self.ymax - self.ymin
end

function AABB:area()
	return (self.xmax - self.xmin) * (self.ymax - self.ymin)
end

function AABB:diagonal()
	local min = Vector.new { xmin, ymin }
	local max = Vector.new { xmax, ymax }

	return Vector.toLength(min, max)
end

-- This is a bad name but I like it.
-- It moves the AABB so that the centre is 0,0 but keeps the width and height.
function AABB:originate()
	local hw = 0.5 * self:width()
	local hh = 0.5 * self:height()

	self.xmin = -hw
	self.xmax = hw
	self.ymin = -hh
	self.ymax = hh
end

function AABB:moveTo( point )
	local x, y = point[1], point[2]
	local hw = 0.5 * self:width()
	local hh = 0.5 * self:height()

	self.xmin = x - hw
	self.xmax = x + hw
	self.ymin = y - hh
	self.ymax = y + hh
end

function AABB:intersects( other )
	local xoverlap = (other.xmin < self.xmax) and (self.xmin < other.xmax)
	local yoverlap = (other.ymin < self.ymax) and (self.ymin < other.ymax)

	return xoverlap and yoverlap
end

function AABB:scale( factor )
	local centre = self:centre()

	local hw = self:width() * 0.5
	local hh = self:height() * 0.5

	self.xmin = self.xmin + (hw * factor)
	self.xmax = self.xmax - (hw * factor)
	self.ymin = self.ymin + (hh * factor)
	self.ymax = self.ymax - (hh * factor)
end

local _axes = {
	horz = 'horz',
	vert = 'vert',
}

function AABB:split( axis, coord )
	assert(_axes[axis])

	if axis == 'horz' then
		assert(self.xmin < coord and coord < self.xmax)

		local sub1 = AABB.new(self)
		local sub2 = AABB.new(self)

		sub1.xmax = coord
		sub2.xmin = coord

		return sub1, sub2
	else
		assert(self.ymin < coord and coord < self.ymax)

		local sub1 = AABB.new(self)
		local sub2 = AABB.new(self)

		sub1.ymax = coord
		sub2.ymin = coord

		return sub1, sub2
	end
end

function AABB:shrink( amount )
	assert(amount < self:width() * 0.5)
	assert(amount < self:height() * 0.5)

	return AABB.new {
		xmin = self.xmin + amount,
		xmax = self.xmax - amount,
		ymin = self.ymin + amount,
		ymax = self.ymax - amount,
	}
end

function AABB:expand( amount )
	self:shrink(-amount)
end

function AABB:centre()
	return Vector.new {
		self.xmin + self:width() * 0.5,
		self.ymin + self:height() * 0.5,
	}
end

-- The smallest square AABB that contains the aabb.
function AABB:square()
	local w, h = self:width(), self:height()
	local cx, cy = self.xmin + w * 0.5, self.ymin + h * 0.5

	local result

	if w > h then
		result = AABB.new {
			xmin = self.xmin,
			xmax = self.xmax,
			ymin = cy - w * 0.5,
			ymax = cy + w * 0.5,
		}
	else
		result = AABB.new {
			xmin = cx - h * 0.5,
			xmax = cx + h * 0.5,
			ymin = self.ymin,
			ymax = self.ymax,
		}
	end

	assert(result:width() == result:height())

	return result
end

function AABB:contains( point )
	local x, y = point[1], point[2]

	return self.xmin <= x and x <= self.xmax and self.ymin <= y and y <= self.ymax
end

-- Take a point relative to the centre of self and transform it to the similar
-- place in the other AABB.
function AABB:lerpTo( point, other )
	return Vector.new {
		lerpf(point[1], self.xmin, self.xmax, other.xmin, other.xmax),
		lerpf(point[2], self.ymin, self.ymax, other.ymin, other.ymax),
	}
end

-- Englarge the AABB to be able to fit the AABB at any possible rotation.
function AABB:rotationSafe()
	local diagonal = Vector.new { self:width(), self:height() }
	local halfDiagonalLength = diagonal:length() * 0.5

	local centre = self:centre()

	self.xmin = centre[1] - halfDiagonalLength
	self.xmax = centre[1] + halfDiagonalLength
	self.ymin = centre[2] - halfDiagonalLength
	self.ymax = centre[2] + halfDiagonalLength
end

-- Grow self to have the same proportions as other.
function AABB:similarise( other )
	local w, h = self:width(), self:height()
	local aspect = w / h
	local otherAspect = other:width() / other:height()
	local centre = self:centre()

	-- Low aspect ratios are taller.
	-- High aspects rations are wider.

	if aspect < otherAspect then
		-- So self is taller, make it wider.
		local factor = otherAspect / aspect
		-- print('taller', factor)
		local offset = w * 0.5 * factor

		self.xmin = centre[1] - offset
		self.xmax = centre[1] + offset
	else
		-- So self is wider, make it taller.
		-- local factor = aspect / otherAspect
		local factor = aspect / otherAspect
		-- print('wider', factor)
		local offset = h * 0.5 * factor

		self.ymin = centre[2] - offset
		self.ymax = centre[2] + offset
	end

	-- assert(self:width() > w or self:height() > h)
end

function AABB:merge( other )
	self.xmin = math.min(self.xmin, other.xmin)
	self.xmax = math.max(self.xmax, other.xmax)
	self.ymin = math.min(self.ymin, other.ymin)
	self.ymax = math.max(self.ymax, other.ymax)
end

local test1 = AABB.new {
	xmin = 0,
	xmax = 2,
	ymin = 0,
	ymax = 1
}

local test2 = AABB.new {
	xmin = 0,
	xmax = 1,
	ymin = 0,
	ymax = 2,
}

print(test1:width(), test1:height())
print(test2:width(), test2:height())
test1:similarise(test2)
print(test1:width(), test1:height())

local test1 = AABB.new {
	xmin = 0,
	xmax = 1,
	ymin = 0,
	ymax = 3
}

local test2 = AABB.new {
	xmin = 0,
	xmax = 3,
	ymin = 0,
	ymax = 1,
}

print(test1:width(), test1:height())
print(test2:width(), test2:height())
test1:similarise(test2)
print(test1:width(), test1:height())
