require 'AABB'
require 'Graph'
require 'Vector'
require 'graph2D'
require 'Quadtree'
require 'Voronoi'
require 'geometry'
require 'terrains'

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
--     terrain = terrains.<name>
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

-- TODO: this can generate points that are too close together so corridors end
--       up merging. Might need to use path finding code instead...
local function _corridors( graph, margin )
	-- Now create corridor the points along the edges.
	local points = {}

	for edge, verts in pairs(graph.edges) do
		if not edge.cosmetic then
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
						terrain = terrains.corridor,
					}

					points[#points+1] = point
				end			
			end
		end
	end

	return points
end

-- TODO: this avoids the overlapping issue with _corridors() above. This issue
--       with this is that the halfedges between cells can be very small.
local function _aStarCorridors( roomGraph, graph, margin )
	-- Now create corridor the points along the edges.
	local vertices = {}

	for edge, verts in pairs(roomGraph.edges) do
		if not edge.cosmetic then
			local room1, room2 = verts[1].room, verts[2].room

			-- Choose the nearest two vertices of the two rooms to connect.
			local distance, near1, near2 = Vector.nearest(room1.points, room2.points)

			-- This should always succeed.
			if near1 and near2 then
				local success, path = graph2D.aStar(graph, near1, near2,
					function ( fromVertex, toVertex )
						local length = graph.vertices[fromVertex][toVertex].length
						print('edgeLength', length, margin * 0.5)
						if length > margin * 0.5 then
							local isWall = not toVertex.terrain.walkable
							local isTarget = toVertex == near2

							return isWall or isTarget
						end

						return false
					end)

				assert(success)

				printf('[path] #%d', #path)

				for _, vertex in ipairs(path) do
					if vertex.terrain == terrains.wall then
						vertex.terrain = terrains.corridor
					end
				end
			end
		end
	end

	return vertices
end

-- This is technically a slow algorithm but seems to be ok in practise.
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

		assert(x ~= 1 and x ~= width)
		assert(y ~= 1 and y ~= height)

		local cell = grid.get(x, y)

		if cell then
			cell[#cell+1] = point
		else
			grid.set(x, y, { point })
		end
	end

	local wall = terrains.wall
	
	local result = {}

	-- Now fill a 1 cell thick perimiter with walls.
	for x = 1, width do
		local top = grid.get(x, 1)
		local bottom = grid.get(x, height)

		assert(top == false)
		assert(bottom == false)

		local mx = aabb.xmin + ((x-1) * margin) + (margin * 0.5)

		local topWall = { mx, aabb.ymin + (margin * 0.5), terrain = wall }
		local bottomWall = { mx, aabb.ymax - (margin * 0.5), terrain = wall }

		grid.set(x, 1, { topWall })
		grid.set(x, height, { bottomWall })

		result[#result+1] = topWall
		result[#result+1] = bottomWall
	end

	for y = 2, height-1 do
		local left = grid.get(1, y)
		local right = grid.get(width, y)

		assert(left == false)
		assertf(right == false, '[%d %d]', y, width)

		local my = aabb.ymin + ((y-1) * margin) + (margin * 0.5)

		local leftWall = { aabb.xmin + (margin * 0.5), my, terrain = wall }
		local rightWall = { aabb.xmax - (margin * 0.5), my, terrain = wall }

		grid.set(1, y, { leftWall })
		grid.set(width, y, { rightWall })

		result[#result+1] = leftWall
		result[#result+1] = rightWall
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


	for x = 1, width do
		for y = 1, height do
			for attempt = 1, 10 do
				local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
				local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

				local candidate = { rx, ry, terrain = wall }
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

function Level.newThemed( theme )
	local useAStarConnect = false

	local levelStart = love.timer.getMicroTime()

	local ruleset = themes.loadRuleset(theme)
	local rules = themes.rules(ruleset)

	local grammar = GraphGrammar.new {
		rules = rules,

		springStrength = theme.springStrength,
		edgeLength = theme.edgeLength,
		repulsion = theme.repulsion,
		maxDelta = theme.maxDelta,
		convergenceDistance = theme.convergenceDistance,
		drawYield = false,
		replaceYield = false,
	}

	local maxIterations = theme.maxIterations
	local minVertices = theme.minVertices
	local maxVertices = theme.maxVertices
	local maxValence = theme.maxValence
	local relaxed = nil

	repeat
		relaxed = grammar:build(maxIterations, minVertices, maxVertices, maxValence)

		local yield = false
		graph2D.assignVertexRadiusAndRelax(
			relaxed,
			theme.margin,
			theme.minExtent,
			theme.maxExtent,
			theme.radiusFudge,
			theme.roomgen,
			theme.relaxSpringStrength,
			theme.relaxEdgeLength,
			theme.relaxRepulsion,
			theme.relaxMaxDelta,
			theme.relaxConvergenceDistance,
			yield)
	until not graph2D.isSelfIntersecting(relaxed)

	local rooms = {}

	for vertex, _ in pairs(relaxed.vertices) do
		local points = {}

		for index, relPoint in ipairs(vertex.points) do
			assert(relPoint.terrain)
			points[index] = {
				vertex[1] + relPoint[1],
				vertex[2] + relPoint[2],
				terrain = relPoint.terrain,
			}
		end

		local aabb = Vector.aabb(points)
		local hull = geometry.convexHull(points)

		local room = {
			points = points,
			aabb =  aabb,
			hull = hull,
			vertex = vertex,
		}

		vertex.room = room

		rooms[#rooms+1] = room
	end

	local corridors = {}

	if not useAStarConnect then
		corridors = _corridors(relaxed, theme.margin)

		for i = 1, #corridors-1 do
			for j = i+1, #corridors do
				local corridor1, corridor2 = corridors[i], corridors[j]
				local distance = Vector.toLength(corridor1, corridor2) / theme.margin
				if distance <= 0.75 then
					printf('CORRIDOR TOO CLOSE %d %d = %.2f', i, j, distance)
				end
			end
		end
	end

	-- Create a list of all points then enclose them.
	local all = {}

	for index = 1, #rooms do
		local points = rooms[index].points

		for j = 1, #points do
			assert(points[j].terrain)
			all[#all+1] = points[j]
		end
	end

	for index = 1, #corridors do
		all[#all+1] = corridors[index]
	end

	-- Ensure the map is surrounded by wall so expand the AABB a bit.
	local safe = Vector.aabb(all):shrink(-3 * theme.margin)
	local walls = _enclose(all, safe, theme.margin)

	for _, wall in ipairs(walls) do
		all[#all+1] = wall
	end

	-- Build voronoi diagram.
	local sites = {}

	for index, point in ipairs(all) do
		local site = {
			x = point[1],
			y = point[2],
			vertex = point,
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

	-- From voronoi diagram create a cell connectivity graph.
	local graph = Graph.new()

	-- First add the vertices and contruct the polygon for the vertices.
	for _, cell in ipairs(diagram.cells) do
		local vertex = all[cell.site.index]

		local poly = {}

		for _, halfedge in ipairs(cell.halfedges) do
			local startpoint = halfedge:getStartpoint()

			poly[#poly+1] = startpoint.x
			poly[#poly+1] = startpoint.y
		end

		vertex.poly = poly

		graph:addVertex(vertex)
	end

	-- Now the connections.
	for _, cell in ipairs(diagram.cells) do
		local neighbours = cell:getNeighborIdAndEdgeLengths()

		local vertex1 = all[cell.site.index]

		for _, neighbour in ipairs(neighbours) do
			local vertex2 = all[diagram.cells[neighbour.voronoiId].site.index]
			
			if not graph:isPeer(vertex1, vertex2) then
				graph:addEdge({ length = neighbour.edgeLength }, vertex1, vertex2)
			end
		end
	end

	if useAStarConnect then
		corridors = _aStarCorridors(relaxed, graph, theme.margin)
	end

	-- TEST: to save trying to write straight skeleton generating code.
	-- RESULT: it works but is quite slow and only works for single cells.
	local offsetStart = love.timer.getMicroTime()

	local offset = theme.margin * 0.2
	local cores = {}
	local voronoi = Voronoi:new()
	local wall = terrains.wall

	for _, cell in ipairs(diagram.cells) do
		if cell.site.vertex.terrain.walkable and false then
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
		aabb = safe,
		rooms = rooms,
		corridors = corridors,
		walls = walls,
		all = all,
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
