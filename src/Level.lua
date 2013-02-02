require 'AABB'
require 'Graph'
require 'Vector'
require 'graph2D'
require 'Quadtree'

local V = Vector.new
local VN = Vector.normal

Level = {}

Level.__index = Level

local function _connect( graph, rooms )
	local centres = {}

	for _, room in ipairs(rooms) do
		local xmin, ymin = math.huge, math.huge
		local xmax, ymax = -math.huge, -math.huge

		for vertex, _ in pairs(room.vertices) do
			local x, y = vertex[1], vertex[2]
			xmin = math.min(xmin, x)
			ymin = math.min(ymin, y)
			xmax = math.max(xmax, x)
			ymax = math.max(ymax, y)
		end

		local centre = Vector.new {
			xmin + (0.5 * (xmax - xmin)),
			ymin + (0.5 * (ymax - ymin)),
		}

		centre.room = room

		centres[#centres+1] = centre
	end

	local skele = graphgen.rng(centres)

	for edge, verts in pairs(skele.edges) do
		local room1, room2 = verts[1].room, verts[2].room

		local mindist = math.huge
		local near1, near2 = nil, nil

		for vertex1, _ in pairs(room1.vertices) do
			for vertex2, _ in pairs(room2.vertices) do
				local distance = Vector.toLength(vertex1, vertex2)

				if distance < mindist then
					mindist = distance
					near1, near2 = vertex1, vertex2
				end
			end
		end

		if near1 and near2 then
			graph:addEdge({ length = mindist, corridor = true }, near1, near2)
		end
	end
end


local function _enclose( graph, aabb, margin )
	print('_enclose()')

	local width = math.ceil(aabb:width() / margin)
	local height = math.ceil(aabb:height() / margin)

	margin = aabb:width() / width

	local grid = newgrid(width, height, false)

	for vertex, _ in pairs(graph.vertices) do
		local x = math.round((vertex[1] - aabb.xmin) / margin)
		local y = math.round((vertex[2] - aabb.ymin) / margin)

		local cell = grid.get(x, y)

		if cell then
			cell[#cell+1] = vertex
		else
			grid.set(x, y, { vertex })
		end
	end

	grid.print()

	local dirs = {
		{ -1, -1 },
		{  0, -1 },
		{  1, -1 },
		{ -1,  0 },
		{  1,  0 },
		{ -1,  1 },
		{  0,  1 },
		{  1,  1 },
	}

	for x= 1, width do
		for y = 1, height do
			if not grid.get(x, y) then
				-- local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
				-- local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

				local rx = aabb.xmin + ((x-1) * margin) + (margin * 0.5) + (margin * math.random() * 0.25)
				local ry = aabb.ymin + ((y-1) * margin) + (margin * 0.5) + (margin * math.random() * 0.25)

				local candidate = { rx, ry, wall = true }
				local empty = {}
				local accepted = true

				for _, dir in ipairs(dirs) do
					local dx, dy = x + dir[1], y + dir[2]
					
					if 1 <= dx and dx <= width and 1 <= dy and dy <= height then
						for _, vertex in ipairs(grid.get(dx, dy) or empty) do
							if Vector.toLength(vertex, candidate) < margin then
								accepted = false
								break
							end
						end
					end

					if not accepted then
						break
					end
				end

				if accepted then
					graph:addVertex(candidate)
				end
			end
		end
	end
end


-- aabb - the size of the level
-- margin - the minimum distance between vertices
-- layout - layoutgen function
-- roomgen - roomgen function
-- graphgen - graphgen function

function Level.new( params )
	-- local aabb = AABB.new(params.aabb)
	local aabb = params.aabb:shrink(params.margin)
	local margin = params.margin
	local layout = params.layout
	local roomgen = params.roomgen
	local limits = params.limits or {
		minwidth = 100,
		minheight = 100,
		maxwidth = 400,
		maxheight = 400,
		margin = margin,
		maxboxes = 1,
		point1s = nil,
		point2s = nil,
	}

	-- 1. get the rooms AABBs.
	local aabbs = layout(aabb, limits)

	printf('#aabbs:%d', #aabbs)

	-- 2. get point lists for each room.
	local rooms = {}
	for index = 1, #aabbs do
		local aabb = aabbs[index]

		local points
		repeat
			points = roomgen(aabb, margin)
		until #points > 0

		rooms[index] = {
			points = points,
			index = index,
			aabb = aabb,
		}
	end

	-- 3. insert all the points into a quadtree.
	local quadtree = Quadtree.new(aabb)

	for index = 1, #rooms do
		local points = rooms[index].points

		for j = 1, #points do
			quadtree:insert(points[j], index)
		end
	end

	local result = {
		aabb = aabb,
		rooms =rooms,
		quadtree = quadtree,
	}

	setmetatable(result, Level)

	return result
end

function Level:distanceMap( source, maxdepth )
	return self.graph:distanceMap(source, maxdepth)
end

function Level:points()
	if not self.point1s then
		local point1s, point2s = {}, {}

		for edge, endverts in pairs(self.graph.edges) do
			local vertex1, vertex2 = endverts[1], endverts[2]
			point1s[#point1s+1] = { vertex1[1], vertex1[2] }
			point2s[#point2s+1] = { vertex2[1], vertex2[2] }
		end

		self.point1s, self.point2s = point1s, point2s
	end

	return self.point1s, self.point2s
end
