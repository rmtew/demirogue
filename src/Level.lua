require 'AABB'
require 'Graph'
require 'Vector'
require 'graph2D'
require 'Quadtree'
require 'Voronoi'

local V = Vector.new
local VN = Vector.normal

Level = {}

Level.__index = Level

-- Uses a relative neighbourhood graph to connect the rooms.
local function _connect( rooms, margin )
	local centres = {}

	for index, room in ipairs(rooms) do
		local centre = room.aabb:centre()
		centre.room = room
		centres[index] = centre
	end

	local skele = graphgen.rng(centres)

	-- Now create the points along the edges.

	local points = {}

	for edge, verts in pairs(skele.edges) do
		local room1, room2 = verts[1].room, verts[2].room

		local distance, near1, near2 = Vector.nearest(room1.points, room2.points)

		if near1 and near2 then
			-- distance / margin 
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


local function _enclose( points, aabb, margin )
	print('_enclose()')

	local width = math.ceil(aabb:width() / margin)
	local height = math.ceil(aabb:height() / margin)

	print('margin', margin)

	margin = aabb:width() / width

	print('margin', margin)

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

	for x= 1, width do
		for y = 1, height do
			-- if not grid.get(x, y) then
				for attempt = 1, 10 do
					-- local rx = aabb.xmin + ((x-1) * margin) + (margin * math.random())
					-- local ry = aabb.ymin + ((y-1) * margin) + (margin * math.random())

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
						-- break
					end
				end
			-- end
		end
	end

	return result
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
		maxboxes = 40,
		point1s = nil,
		point2s = nil,
	}

	-- 1. get the rooms borders.
	local borders = layout(aabb, limits)

	printf('#borders:%d', #borders)

	-- 2. get point lists for each room.
	local rooms = {}
	for index = 1, #borders do
		local border = borders[index]

		local points
		repeat
			points = roomgen(border, margin)
		until #points > 0

		local aabb = Vector.aabb(points)

		rooms[index] = {
			points = points,
			index = index,
			aabb = aabb,
			border = border,
		}
	end

	-- 3. connect the rooms.
	local corridors = _connect(rooms, margin)

	-- 4. insert all the room and corridor points into a quadtree.
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

	local walls = _enclose(all, params.aabb, margin)

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
		}

		sites[#sites+1] = site
	end

	local bbox = {
		xl = params.aabb.xmin,
		xr = params.aabb.xmax,
		yt = params.aabb.ymin,
		yb = params.aabb.ymax,
	}

	local start = love.timer.getMicroTime()
	diagram = Voronoi:new():compute(sites, bbox)
	local finish = love.timer.getMicroTime()

	printf('Voronoi:compute(%d) %.3fs', #sites, finish - start)


	local result = {
		aabb = aabb,
		rooms =rooms,
		corridors = corridors,
		walls = walls,
		all = all,
		quadtree = quadtree,
		diagram = diagram,
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
