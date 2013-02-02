
Quadtree = {}
Quadtree.__index = Quadtree

-- node = {
--     point = { x, y },
--     data = ...,
--     aabb = <AABB>,
--     <NW> = node | nil,
--     <NE> = node | nil,
--     <SW> = node | nil,
--     <SE> = node | nil,
-- }
--
--
--

function Quadtree.new( aabb )
	assert(aabb:width() > 0)
	assert(aabb:height() > 0)

	local result = {
		root = nil,
		aabb = AABB.new(aabb),
		square = aabb:square(),
	}

	setmetatable(result, Quadtree)

	return result
end

-- Assumes the point has already been checked for being in the AABB
local function _quadrant( aabb, point )
	local cx = aabb.xmin + (aabb.xmax - aabb.xmin) * 0.5
	local cy = aabb.ymin + (aabb.ymax - aabb.ymin) * 0.5

	local x, y = point[1], point[2]

	if y > cy then
		if x < cx then
			return 1 -- NW
		else
			return 2 -- NE
		end
	else
		if x < cx then
			return 3 -- SW
		else
			return 4 -- SE
		end
	end
end

local function _childAABB( parent, quadrant )
	assert(1 <= quadrant and quadrant <= 4)

	local aabb = parent.aabb
	
	local xmin, xmax = aabb.xmin, aabb.xmax
	local ymin, ymax = aabb.ymin, aabb.ymax

	local cx = xmin + (xmax - xmin) * 0.5
	local cy = ymin + (ymax - ymin) * 0.5

	if quadrant < 3 then
		-- N(W|E)
		ymin = cy
	else
		-- S(W|E)
		ymax = cy
	end

	-- quadrant & 1
	if quadrant == 1 or quadrant == 3 then
		-- (N|S)W
		xmax = cx
	else
		-- (N|S)E
		xmin = cx
	end

	return AABB.new {
		xmin = xmin,
		xmax = xmax,
		ymin = ymin,
		ymax = ymax,
	}
end

function Quadtree:insert( point, data )
	if not self.aabb:contains(point) then
		return false
	end

	local node = self.root

	if not node then
		self.root = {
			point = point,
			data = data,
			aabb = self.square,
			nil,
			nil,
			nil,
			nil,
		}
	else
		while true do
			local quadrant = _quadrant(node.aabb, point)
			local child = node[quadrant]

			if child then
				node = child
			else
				node[quadrant] = {
					point = point,
					data = data,
					aabb = _childAABB(node, quadrant),
					nil,
					nil,
					nil,
					nil,
				}
				break
			end
		end
	end
	print('done')

	return true
end
