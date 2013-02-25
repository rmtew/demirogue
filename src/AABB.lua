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

	assert(result.xmin <= result.xmax)
	assert(result.ymin <= result.ymax)

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


