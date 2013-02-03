--
-- Quadtree.lua
--
-- 
-- 


Quadtree = {}
Quadtree.__index = Quadtree

-- branch = {
--     aabb = <AABB>,
--     <NW> = node | leaf,
--     <NE> = node | leaf,
--     <SW> = node | leaf,
--     <SE> = node | leaf,
-- }
--
-- leaf = {
--     leaf = true,
--     aabb = <AABB>,
--     point = { x, y },
--     data = ...
-- }
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

local function _subdivide( node )
	assert(node.leaf)
	assert(node.point)

	local aabb = node.aabb
	local xmin, xmax = aabb.xmin, aabb.xmax
	local ymin, ymax = aabb.ymin, aabb.ymax

	local cx = xmin + (xmax - xmin) * 0.5
	local cy = ymin + (ymax - ymin) * 0.5

	local nw = {
		leaf = true,
		aabb = AABB.new {
			xmin = xmin,
			xmax = cx,
			ymin = cy,
			ymax = ymax,
		},
		point = nil,
		data = nil,
	}

	local ne = {
		leaf = true,
		aabb = AABB.new {
			xmin = cx,
			xmax = xmax,
			ymin = cy,
			ymax = ymax,
		},
		point = nil,
		data = nil,
	}

	local sw = {
		leaf = true,
		aabb = AABB.new {
			xmin = xmin,
			xmax = cx,
			ymin = ymin,
			ymax = cy,
		},
		point = nil,
		data = nil,
	}

	local se = {
		leaf = true,
		aabb = AABB.new {
			xmin = cx,
			xmax = xmax,
			ymin = ymin,
			ymax = cy,
		},
		point = nil,
		data = nil,
	}

	local result =  {
		aabb = node.aabb,
		nw,
		ne,
		sw,
		se,
	}

	assert(not result.leaf)
	assert(#result == 4)

	local point = node.point
	local x, y = point[1], point[2]
	local index

	if y > cy then
		if x < cx then
			index = 1 -- NW
		else
			index = 2 -- NE
		end
	else
		if x < cx then
			index = 3 -- SW
		else
			index = 4 -- SE
		end
	end

	local child = result[index]

	child.point = node.point
	child.data = node.data

	return result
end

function Quadtree:_insert( node, parent, index, point, data )
	if not node.aabb:contains(point) then
		return false
	end

	-- There's three things the node can be:
	-- - branch in which case recurse
	-- - an unpopulated leaf, set the point and data and be done.
	-- - a populated leaf, subdivide then recurse

	if node.leaf then
		if not node.point then
			node.point = point
			node.data = data

			return true
		else
			node = _subdivide(node)

			if not parent then
				self.root = node
			else
				parent[index] = node
			end
		end
	end

	for index = 1, 4 do
		if self:_insert(node[index], node, index, point, data) then
			return true
		end
	end

	error('should never happen')

	return false
end


function Quadtree:insert( point, data )
	if not self.aabb:contains(point) then
		return false
	end

	local root = self.root

	if root then
		return self:_insert(root, nil, nil, point, data)
	else
		self.root = {
			leaf = true,
			point = point,
			data = data,
			aabb = self.square,
		}
	end

	return true
end
