--
-- graph2D.lua
--
-- Utility functions of graphs with vertices that're 2D vectors.
-- 

require 'Graph'
require 'Vector'
require 'graphgen'

graph2D = {}

function graph2D.aabb( graph )
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

function graph2D.nearest( graph1, graph2 )
	local mindist = math.huge
	local near1, near2 = nil, nil

	for vertex1, _ in pairs(graph1.vertices) do
		for vertex2, _ in pairs(graph2.vertices) do
			local distance = Vector.toLength(vertex1, vertex2)

			if distance < mindist then
				mindist = distance
				near1, near2 = vertex1, vertex2
			end
		end
	end

	return mindist, near1, near2
end


function graph2D.connect( graph, rooms )
	local centres = {}

	for _, room in ipairs(rooms) do
		local centre = graph2D.aabb(room):centre()

		centre.room = room

		centres[#centres+1] = centre
	end

	local skele = graphgen.rng(centres)

	for edge, verts in pairs(skele.edges) do
		local room1, room2 = verts[1].room, verts[2].room
		local mindist, near1, near2 = graph2D.nearest(room1, room2)

		if near1 and near2 then
			graph:addEdge({ length = mindist }, near1, near2)
		end
	end
end

function graph2D.subdivide( graph, margin )
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