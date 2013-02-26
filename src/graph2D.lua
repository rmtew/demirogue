--
-- graph2D.lua
--
-- Utility functions of graphs with vertices that're 2D vectors.
-- 

require 'Graph'
require 'Vector'
require 'graphgen'
require 'AABB'

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

function graph2D.matchAABB( match )
	local xmin, xmax = math.huge, -math.huge
	local ymin, ymax = math.huge, -math.huge

	for _, vertex in pairs(match) do
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

-- For each vertex with more than one incident edge sort the edges by their
-- angle and calculate the signed angle between neighboring edges.
function graph2D.spurs( graph )
	-- { [vertex] = { { edge1 , edge2, signedAngle} }+ }*
	local result = {}
	for vertex, peers in pairs(graph.vertices) do
		-- Create an array of edges, sorted by their angle.
		local winding = {}

		for other, edge in pairs(peers) do
			local to = Vector.to(vertex, other)
			local angle = math.atan2(to[2], to[1])
			winding[#winding+1] = { angle = angle, edge = edge, to = to }
		end

		if #winding >= 2 then
			table.sort(winding,
				function ( lhs, rhs )
					return lhs.angle < rhs.angle
				end)

			local edgePairs = {}

			-- Now create the lists of edge pairs with signed angles between them.
			for index = 1, #winding do
				local winding1 = winding[index]
				local nextIndex = (index < #winding) and index or 1
				local winding2 = winding[nextIndex]

				local edge1, to1 = winding1.edge, winding1.to
				local edge2, to2 = winding2.edge, winding2.to

				edgePairs[#edgePairs+1] = {
					edge1 = edge1,
					edge2 = edge2,
					signedAngle = to1:signedAngle(to2),
				}
			end

			result[vertex] = edgePairs
		end
	end

	return result
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

-- Moves the graphs vertices.
function graph2D.forceDraw( graph, springStrength, edgeLength, repulsion, maxDelta, convergenceDistance, yield )
	-- assert(convergenceDistance < maxDelta)

	local forces = {}
	local positions = {}
	local vertices = {}

	for vertex, _ in pairs(graph.vertices) do
		forces[vertex] = Vector.new { 0, 0 }
		positions[vertex] = Vector.new { 0, 0 }
		vertices[#vertices+1] = vertex
	end


	local converged = false
	local edgeForces = false

	while not converged do
		for i = 1, #vertices do
			local vertex = vertices[i]
			local peers = graph.vertices[vertex]

			-- Vertex-vertex forces.
			for j = i+1, #vertices do
				local other = vertices[j]
				assert(vertex ~= other)

				if peers[other] then
					local to = Vector.to(vertex, other)
					local d = to:length()

					-- Really short vectors cause trouble.
					d = math.max(d, 0.5)

					local f = -springStrength * math.log(d/edgeLength)

					--print('spring', f)

					local vforce = forces[vertex]
					local oforce = forces[other]

					vforce[1] = vforce[1] - (to[1] * f)
					vforce[2] = vforce[2] - (to[2] * f)

					oforce[1] = oforce[1] + (to[1] * f)
					oforce[2] = oforce[2] + (to[2] * f)
				else
					local to = Vector.to(vertex, other)
					local d = to:length()

					-- Really short vectors cause trouble.
					d = math.max(d, 0.5)

					local f = repulsion / (d*d)

					--print('repulse', f)

					local vforce = forces[vertex]
					local oforce = forces[other]

					vforce[1] = vforce[1] - (to[1] * f)
					vforce[2] = vforce[2] - (to[2] * f)

					oforce[1] = oforce[1] + (to[1] * f)
					oforce[2] = oforce[2] + (to[2] * f)
				end

			end

			if edgeForces then
				-- Now edge-edge forces.
				local edges = {}
				for other, edge in pairs(peers) do
					local to = Vector.to(vertex, other)
					local angle = math.atan2(to[2], to[1])

					edges[#edges+1] = { angle, edge, other, to }
				end

				if #edges >= 2 then
					-- This puts the edges into counter-clockwise order.
					table.sort(edges,
						function ( lhs, rhs )
							return lhs[1] < rhs[1]
						end)

					for index = 1, #edges do
						local angle1, edge1, other1, to1 = unpack(edges[index])
						local nextIndex = (index == #edges) and 1 or index+1
						local angle2, edge2, other2, to2 = unpack(edges[nextIndex])

						local edgeRepulse = 3
						-- -- local edgeLength = ...
						-- local to1Length = to1:length()
						-- local to2Length = to2:length()
						-- local el = edgeLength
						-- local angleRepulse = 1

						-- local fEdge = edgeRepulse * (math.atan(to1Length/el) + math.atan(to2Length/el))
						-- local theta = math.acos(to1:dot(to2)) / (to1Length * to2Length)
						-- local fTheta = angleRepulse * (1/math.tan(theta * 0.5))

						if to1:length() > 0.001 and to2:length() > 0.001 then
							to1:normalise()
							to2:normalise()
							local dot = to1:dot(to2)

							local f = edgeRepulse * dot

							local o1force = forces[other1]
							local o2force = forces[other2]

							local dir1 = to1:antiPerp()
							local dir2 = to2:perp()

							o1force[1] = o1force[1] + (dir1[1] * f)
							o1force[2] = o1force[2] + (dir1[2] * f)

							o2force[1] = o2force[1] + (dir2[1] * f)
							o2force[2] = o2force[2] + (dir2[2] * f)
						end
					end
				end
			end
		end

		converged = true

		for _, vertex in ipairs(vertices) do
			local force = forces[vertex]
			local l = force:length()

			if l > convergenceDistance then
				converged = false
				if l > maxDelta then
					force:scale(maxDelta/l)
					-- assert(force:length() < l)
				end
			end

			vertex[1] = vertex[1] + force[1]
			vertex[2] = vertex[2] + force[2]
		end

		-- TODO: got a weird problem where the edgeForces make the graph fly
		--       off in the same direction for ever :^(
		-- if converged and not edgeForces then
		-- 	converged = false
		-- 	edgeForces = true
		-- end

		if yield then
			coroutine.yield(graph, forces)
		end
	end
end