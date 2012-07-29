--
-- Graph2D.lua
--
-- Utility functions of graphs with vertices that're 2D vectors.
-- 

require 'Graph'
require 'Vector'

Graph2D = {}

function Graph2D.aabb( graph )
	local xmin, xmax = math.huge, -math.huge
	local ymin, ymax = math.huge, -math.huge

	for vertex, _ in pairs(graph.vertices) do
		xmin = math.min(xmin, vertex[1])
		xmax = math.max(xmax, vertex[1])
		ymin = math.min(ymin, vertex[2])
		ymax = math.max(ymax, vertex[2])
	end

	return AABB.new {
		xmin = xmin,
		xmax = xmax,
		ymin = ymin,
		ymax = ymax,
	}
end


function Graph2D.connect( graph, rooms )
	local centres = {}

	for _, room in ipairs(rooms) do
		local centre = Graph2D.aabb(room):centre()

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