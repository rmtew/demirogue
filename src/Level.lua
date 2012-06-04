require 'AABB'
require 'Graph'
require 'Vector'

local V = Vector.new
local VN = Vector.normal

Level = {
	Dir = {
		N = 'N',
		E = 'E',
		S = 'S',
		W = 'W',
		NE = 'NE',
		SE = 'SE',
		SW = 'SW',
		NW = 'NW',
	},
	DirToVec = {
		N = V {  0, -1 },
		E = V {  1,  0 },
		S = V {  0,  1 },
		W = V { -1,  0 },
		NE = VN {  1, -1 },
		SE = VN {  1,  1 },
		SW = VN { -1,  1 },
		NW = VN { -1, -1 },
	},
	Opposite = {
		N = 'S',
		E = 'W',
		S = 'N',
		W = 'E',
		NE = 'SW',
		SE = 'NW',
		SW = 'NE',
		NW = 'SE',
	},
}

Level.__index = Level

local Dir = Level.Dir
local DirToVec = Level.DirToVec
local Opposite = Level.Opposite


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
			graph:addEdge({ length = mindist }, near1, near2)
		end
	end
end

local function _edgecheck( graph )
	local deathrow = {}

	for vertex, peers in pairs(graph.vertices) do
		-- We need to map edges to directions.
		local diredges = {}
		local dirdots = {}

		for other, edge in pairs(peers) do
			local disp = Vector.to(vertex, other):normalise()

			local maxdot = math.cos(math.pi / 8)
			local neardir = nil

			for dir, vec in pairs(DirToVec) do
				local dot = disp:dot(vec)

				if maxdot <= dot then
					maxdot = dot
					neardir = dir
				end
			end

			assert(neardir)

			local diredge = diredges[neardir]
			local dirdot = dirdots[neardir]

			if not diredge or dirdot < maxdot then
				diredges[neardir] = edge
				dirdots[neardir] = maxdot

				if diredge then
					deathrow[diredge] = true
				end
			end
		end

		for dir, edge in pairs(diredges) do
			if vertex == graph.edges[edge][1] then
				edge.dir1to2 = dir
			else
				edge.dir2to1 = dir
			end
		end
	end

	for edge, _ in pairs(graph.edges) do
		local dir1to2, dir2to1 = edge.dir1to2, edge.dir2to1

		if not dir1to2 or not dir2to1 or edge.dir1to2 ~= Opposite[edge.dir2to1] then
			deathrow[edge] = true
		end
	end

	for edge, _ in pairs(deathrow) do
		graph:removeEdge(edge)
	end

	for vertex, peers in pairs(graph.vertices) do
		local dirs = {}

		for other, edge in pairs(peers) do
			local endverts = graph.edges[edge]
			
			if vertex == endverts[1] then
				dirs[edge.dir1to2] = other
			else
				dirs[edge.dir2to1] = other
			end
		end

		vertex.dirs = dirs
	end
end

local function _subdivide( graph, margin )
	local subs = {}

	for edge, endverts in pairs(graph.edges) do
		local numpoints = math.floor(Vector.toLength(endverts[1], endverts[2]) / margin) - 1

		if numpoints > 0 then
			local length = edge.length / (numpoints + 1)
			local start, finish = endverts[1], endverts[2]
			assert(start ~= finish)
			local normal = Vector.to(start, finish):normalise()

			local vertices = { start }

			for i = 1, numpoints do
				local vertex = Vector.new {
					start[1] + (i * length * normal[1]),
					start[2] + (i * length * normal[2]),
				}

				vertex.subdivide = true

				graph:addVertex(vertex)

				vertices[#vertices+1] = vertex
			end

			vertices[#vertices+1] = finish

			subs[#subs+1] = {
				vertices = vertices,
				length = length,
			}
			
			graph:removeEdge(edge)
		end
	end

	for _, sub in ipairs(subs) do
		for i = 1, #sub.vertices-1 do
			graph:addEdge({ length = sub.length }, sub.vertices[i], sub.vertices[i+1])
		end
	end
end


-- aabb - the size of the level
-- margin - the minimum distance between vertices
-- layout - layoutgen function
-- roomgen - roomgen function
-- graphgen - graphgen function

function Level.new( params )
	local aabb = AABB.new(params.aabb)
	local margin = params.margin
	local layout = params.layout
	local roomgen = params.roomgen
	local graphgen = params.graphgen

	local limits = {
		minwidth = 100,
		minheight = 100,
		margin = margin,
		maxboxes = 45,
	}

	local boxes = layout(aabb, limits)
	local rooms = {}

	local graph = Graph.new()
	
	for index, box in ipairs(boxes) do
		local room
		repeat
			room = roomgen(box, margin)
		until next(room.vertices)

		for edge, endverts in pairs(room.edges) do
			assert(endverts[1] ~= endverts[2], string.format('%d', index))
		end

		rooms[index] = room

		graph:merge(room)
	end

	_connect(graph, rooms)
	_subdivide(graph, margin)
	_edgecheck(graph)

	local result = {
		aabb = aabb,
		boxes = boxes,
		rooms = rooms,
		graph = graph,
	}

	setmetatable(result, Level)

	return result
end

function Level:distanceMap( source, maxdepth )
	return self.graph:distanceMap(source, maxdepth)
end
