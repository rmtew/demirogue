require 'AABB'
require 'Graph'
require 'Vector'
require 'graph2D'
require 'Quadtree'
require 'Voronoi'
require 'geometry'

local V = Vector.new
local VN = Vector.normal

Level = {}

Level.__index = Level

--
-- TODO: sort out cell/vertex structure. Below is the current setup.
--
-- vertex = {
--     x,
--     y,
--     corridor = true | nil,
--     wall = true | nil,
-- }
--
-- TODO: sort out room structure as well. Below is the current setup.
--
-- room = {
--     points = cell sites/vertices in the room, can't rely on order.
--     aabb   = the tight bounding box of the rooms vertices.
--     border = the original AABB passed into the roomgen.
--     hull   = clockwise list of Vectors representing the convex hull of the vertices.
-- }
--

-- Uses a relative neighbourhood graph (RNG) to connect the rooms.
-- TODO: The results are a little too connected. Play with removing edges.
local function _connect( rooms, margin )
	local centres = {}

	for index, room in ipairs(rooms) do
		local centre = room.aabb:centre()
		centre.room = room
		centres[index] = centre
	end

	-- Relative Neighbourhood Graph ensures no rooms are left unconnected and
	-- is also a bit sparse so we don;t get too much connectivity.
	local skele = graphgen.rng(centres)

	-- Now create corridor the points along the edges.
	local points = {}

	for edge, verts in pairs(skele.edges) do
		local room1, room2 = verts[1].room, verts[2].room

		-- Choose the nearest two points of the two rooms to connect.
		local distance, near1, near2 = Vector.nearest(room1.points, room2.points)

		-- This should always succeed.
		if near1 and near2 then
			-- We already have the end points of the corridor so we only create
			-- the internal points.
			-- TODO: if numPoints < 1 then something has gone wrong, maybe
			--       assert on it. Need to ensure the layoutgen functions
			--       always leave at least 2*margin distance between rooms.
			local numPoints = math.round(distance / margin) - 1
			local segLength = distance / (numPoints + 1)
			local normal = Vector.to(near1, near2):normalise()

			for i = 1, numPoints do
				local point = {
					near1[1] + (i * segLength * normal[1]),
					near1[2] + (i * segLength * normal[2]),
					corridor = true,
				}

				points[#points+1] = point
			end			
		end
	end

	return points
end

-- 1. Put all the points into a margin sized grid of buckets.
-- 2. For each cell try 10 times to create a random point within the cell.
-- 3. Check the point isn't too close (within margin distance) of other points.
local function _enclose( points, aabb, margin )
	local width = math.ceil(aabb:width() / margin)
	local height = math.ceil(aabb:height() / margin)

	-- print('margin', margin)

	margin = aabb:width() / width

	-- print('margin', margin)

	local grid = newgrid(width, height, false)

	for _, point in pairs(points) do
		local x = math.round((point[1] - aabb.xmin) / margin)
		local y = math.round((point[2] - aabb.ymin) / margin)

		local cell = grid.get(x, y)

		if cell then
			cell[#cell+1] = point
		else
			grid.set(x, y, { point })
		end
	end

	-- grid.print()

	-- Any point within a cell could be too close to other cell neighbouring.
	local dirs = {
		{ 0, 0 },
		{ -1, -1 },
		{  0, -1 },
		{  1, -1 },
		{ -1,  0 },
		{  1,  0 },
		{ -1,  1 },
		{  0,  1 },
		{  1,  1 },
	}

	local result = {}

	for x = 1, width do
		for y = 1, height do
			for attempt = 1, 10 do
				local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
				local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

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
					local cell = grid.get(x, y)

					if cell then
						cell[#cell+1] = candidate
					else
						cell = { candidate }
						grid.set(x, y, cell)
					end

					result[#result+1] = candidate
				end
			end
		end
	end

	return result
end


-- aabb - the size of the level
-- margin - the minimum distance between vertices
-- layout - layoutgen function
-- roomgen - roomgen function
-- TODO: limits
-- TODO: if level gen takes too long this needs to run in a coroutine.

function Level.new( params )
	-- local aabb = AABB.new(params.aabb)
	local aabb = params.aabb:shrink(params.margin)
	local margin = params.margin
	local layout = params.layout
	local roomgen = params.roomgen
	-- These are limits on room sizes and count.
	-- TODO: rename these to something more obvious.
	local limits = params.limits or {
		minwidth = 100,
		minheight = 100,
		maxwidth = 400,
		maxheight = 400,
		margin = margin,
		maxboxes = 40,
		point1s = nil,
		point2s = nil,
	}

	local levelStart = love.timer.getMicroTime()

	-- TODO: should ensure all points are on integer coordinates.

	-- 1. get the rooms borders.
	local borders = layout(aabb, limits)

	-- TEST: let's kill a quarter of the rooms.
	-- RESULT: better than I though but some of the corridors were too long.
	-- local cull = math.floor(#borders * 0.25)
    --
	-- for i = 1, cull do
	-- 	local victim = math.random(1, #borders)
    --
	-- 	table.remove(borders, victim)
	-- end

	printf('#borders:%d', #borders)

	-- 2. get point lists for each room and create hulls.
	local rooms = {}
	for index = 1, #borders do
		local border = borders[index]

		-- TODO: this is a potentially infinite loop so we need asserts to
		--       protect against it either here or in the layoutgen or roomgen.
		local points
		repeat
			points = roomgen(border, margin)
		until #points > 2

		local aabb = Vector.aabb(points)

		local hull = geometry.convexHull(points)

		-- Check that the convexHull() and isPointInHull() functions work.
		for _, point in ipairs(points) do
			assert(geometry.isPointInHull(point, hull))
		end

		rooms[index] = {
			points = points,
			aabb = aabb,
			border = border,
			hull = hull,
		}
	end

	-- 3. connect the rooms.
	local corridors = _connect(rooms, margin)

	-- 4. insert all the room and corridor points into a quadtree.
	-- TODO: I'm not currently using this for anything. I was going to use it
	--       for enclosing but the current algorithm is good enough.
	local quadtree = Quadtree.new(aabb)

	for index = 1, #rooms do
		local points = rooms[index].points

		for j = 1, #points do
			quadtree:insert(points[j], index)
		end
	end

	for index = 1, #corridors do
		local point = corridors[index]

		-- TODO: need somthing better than -1 to mark a corridor.
		quadtree:insert(point, -1)
	end

	-- 5. create a list of all points then enclose them.
	local all = {}

	for index = 1, #rooms do
		local points = rooms[index].points

		for j = 1, #points do
			all[#all+1] = points[j]
		end
	end

	for index = 1, #corridors do
		all[#all+1] = corridors[index]
	end

	-- We need to ensure the map is surround by wall so expand the AABB a bit.
	local safe = params.aabb:shrink(-margin)
	local walls = _enclose(all, safe, margin)

	for _, wall in ipairs(walls) do
		all[#all+1] = wall
	end

	-- 6. build voronoi diagram.
	local sites = {}

	for index, point in ipairs(all) do
		local site = {
			x = point[1],
			y = point[2],
			wall = point.wall,
			corridor = point.corridor,
			index = index,
		}

		sites[#sites+1] = site
	end

	local bbox = {
		xl = safe.xmin,
		xr = safe.xmax,
		yt = safe.ymin,
		yb = safe.ymax,
	}

	local voronoiStart = love.timer.getMicroTime()
	diagram = Voronoi:new():compute(sites, bbox)
	local voronoiFinish = love.timer.getMicroTime()

	printf('Voronoi:compute(%d) %.3fs', #sites, voronoiFinish - voronoiStart)

	-- 6. from voronoi diagram create a cell connectivity graph.
	local graph = Graph.new()

	-- First add the vertices.
	for _, cell in ipairs(diagram.cells) do
		local vertex = all[cell.site.index]

		graph:addVertex(vertex)
	end

	-- Now the connections.
	for _, cell in ipairs(diagram.cells) do
		local neighbours = cell:getNeighborIds()

		local vertex1 = all[cell.site.index]

		for _, neighbour in ipairs(neighbours) do
			local vertex2 = all[diagram.cells[neighbour].site.index]
			
			if not graph:isPeer(vertex1, vertex2) then
				graph:addEdge({}, vertex1, vertex2)
			end
		end
	end

	-- TEST: to save trying to write straight skeleton generating code.
	-- RESULT: it works but is quite slow and only work for single cells.
	local offsetStart = love.timer.getMicroTime()

	local offset = margin * 0.2
	local cores = {}
	local voronoi = Voronoi:new()

	for _, cell in ipairs(diagram.cells) do
		if not cell.site.wall then
			local neighbours = cell:getNeighborIds()
			local points = { { cell.site.x, cell.site.y } }

			for _, neighbour in ipairs(neighbours) do
				local site = diagram.cells[neighbour].site
				
				points[#points+1] = { site.x, site.y }
			end

			local centre = points[1]
			local sites = { { x = centre[1], y = centre[2], centre = true } }

			for i = 2, #points do
				local point = points[i]
				Vector.advance(point, centre, offset * 2)

				sites[#sites+1] = { x = point[1], y = point[2] }
			end

			local diagram = voronoi:compute(sites, bbox)

			local cell

			for _, candidate in ipairs(diagram.cells) do
				if candidate.site.centre then
					cell = candidate
				end
			end

			assert(cell)
			
			local core = {}

			for _, halfedge in ipairs(cell.halfedges) do
				local startpoint = halfedge:getStartpoint()

				core[#core+1] = startpoint.x
				core[#core+1] = startpoint.y
			end

			if #core >= 6 then
				cores[#cores+1] = core
			end
		end
	end

	local offsetFinish = love.timer.getMicroTime()

	printf('cell offset %.3fs', offsetFinish - offsetStart)

	-- TODO: convert Voronoi representation into something easier to use.
	-- TODO: create cell connectivity graph.

	local levelFinish = love.timer.getMicroTime()

	printf('Level.new() %.3fs', levelFinish - levelStart)

	local result = {
		aabb = aabb,
		rooms = rooms,
		corridors = corridors,
		walls = walls,
		all = all,
		quadtree = quadtree,
		diagram = diagram,
		graph = graph,
		cores = cores,
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
