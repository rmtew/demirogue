--
-- Graph.lua
--
-- An incidence list based graph data structure.
-- There should be nothing game specific in here if possible.
--
-- Simple loops (vertex with an edge to itself) are not allowed.
--
-- Graph = {
--     vertices = {
--         [vertex] = { [vertex] = edge }*
--     }*,
--     edges = {
--         [edge] = { vertex1, vertex2 }
--     }*
-- }
--


Graph = {}
Graph.__index = Graph

function Graph.new( vertices, edges )
	local result = {
		vertices = vertices or {},
		edges = edges or {},
	}

	setmetatable(result, Graph)

	result:_invariant()

	return result
end

function Graph:_invariant()
	local vertices = self.vertices
	local edges = self.edges

	-- 1. Vertices are connected to other vertices by edges.
	for vertex, peers in pairs(vertices) do
		for peer, edge in pairs(peers) do
			assert(vertices[peer])
			assert(edges[edge])
		end
	end

	-- 2. Edges are connected to two distinct vertices.
	for edge, endverts in pairs(edges) do
		local vertex1, vertex2 = endverts[1], endverts[2]

		assert(vertex1)
		assert(vertex2)
		assert(vertex1 ~= vertex2)
		assert(vertices[vertex1])
		assert(vertices[vertex2])
	end
end

function Graph:addVertex( vertex )
	assert(self.vertices[vertex] == nil)

	self.vertices[vertex] = {}

	return vertex
end

function Graph:removeVertex( vertex )
	local vertices = self.vertices
	local edges = self.edges
	local peers = vertices[vertex]

	if peers then
		for peer, edge in pairs(peers) do
			edges[edge] = nil
			vertices[peer][vertex] = nil
		end

		vertices[vertex] = nil
	end
end

function Graph:addEdge( edge, vertex1, vertex2 )
	local peers1 = self.vertices[vertex1]
	local peers2 = self.vertices[vertex2]

	assert(self.edges[edge] == nil)
	assert(vertex1 ~= vertex2) -- No loops.
	assert(peers1 ~= nil and peers1[vertex2] == nil)
	assert(peers2 ~= nil and peers2[vertex1] == nil)
	
	self.edges[edge] = { vertex1, vertex2 }
	peers1[vertex2] = edge
	peers2[vertex1] = edge
end

function Graph:removeEdge( edge )
	local edges = self.edges
	local endverts = edges[edge]

	if endverts then
		local vertices = self.vertices
		local vertex1, vertex2 = endverts[1], endverts[2]

		vertices[vertex1][vertex2] = nil
		vertices[vertex2][vertex1] = nil

		edges[edge] = nil
	end
end

function Graph:merge( other )
	for vertex, peers in pairs(other.vertices) do
		self.vertices[vertex] = peers
	end

	for edge, endverts in pairs(other.edges) do
		self.edges[edge] = endverts
	end
end

-- This should be more efficient that distanceMap(), especially if queue
-- is reused between runs.
function Graph:dmap( source, maxdepth )
	maxdepth = maxdepth or math.huge

	local vertices = self.vertices
	assert(vertices[source])

	local result = { [source] = 0 }
	local queue = { source }

	local index = 1
	local depth = 0

	while index <= #queue and depth < maxdepth do
		depth = depth + 1

		local frontier = #queue

		while index <= frontier do
			local vertex = queue[i]

			for peer, _ in pairs(vertices[vertex]) do
				if not result[peer] then
					result[peer] = depth
					queue[#queue+1] = peer
				end
			end

			index = index + 1
		end
	end

	return result
end

-- TODO: If we could avoid the allocations of all but the result that would be cool
function Graph:distanceMap( source, maxdepth )
	maxdepth = maxdepth or math.huge

	local vertices = self.vertices
	assert(vertices[source])

	local result = { [source] = 0 }
	local frontier = { [source] = true }
	local depth = 0

	while depth < maxdepth and next(frontier) do
		depth = depth + 1
		local newFrontier = {}

		for vertex, _ in pairs(frontier) do
			for peer, _ in pairs(vertices[vertex]) do
				if not frontier[peer] and not result[peer] then
					result[peer] = depth
					newFrontier[peer] = true
				end
			end
		end

		frontier = newFrontier
	end

	return result
end

function Graph:allPairsShortestPaths()
	local result = {}

	local vertices = self.vertices

	for vertex1, peers in pairs(vertices) do
		local weights = {}

		for vertex2, _ in pairs(vertices) do
			if vertex1 == vertex2 then
				weights[vertex2] = 0
			elseif peers[vertex2] then
				weights[vertex2] = 1
			else
				weights[vertex2] = math.huge
			end
		end

		result[vertex1] = weights
	end

	for k in pairs(vertices) do
		for i in pairs(vertices) do
			for j in pairs(vertices) do
				result[i][j] = math.min(result[i][j], result[i][k] + result[k][j])
			end
		end
	end

	return result
end

-- TODO: Brandes algorithm would probably be better.
function Graph:betweenness()
	local paths = self:allPairsShortestPaths()
	local vertices = self.vertices

	local result = {}
	local eccentricities = {}
	local radius = math.huge
	local diameter = 0

	local maxtotal = 0
	local numVertices = table.count(vertices)
	local norm = (numVertices - 1) * (numVertices - 2) * 0.5

	for s in pairs(vertices) do
		local total = 0
		local eccentricity = 0

		for t in pairs(vertices) do
			for u in pairs(vertices) do
				assert(paths[t][u] == paths[u][t])

				if paths[t][u] == paths[t][s] + paths[s][u] and s ~= t and s ~= u and t ~= u then
					total = total + 1
				end
			end
			
			eccentricity = math.max(paths[s][t], eccentricity)
		end
		
		assert(total % 2 == 0)
		total = total * 0.5

		print(s, numVertices, norm, total)
		assert(total <= norm)

		result[s] = total / norm
		eccentricities[s] = eccentricity
		radius = math.min(radius, eccentricity)
		diameter = math.max(diameter, eccentricity)
		maxtotal = math.max(total, maxtotal)
	end

	-- print('maxtotal', maxtotal)

	-- if maxtotal > 0 then
	-- 	for vertex, value in pairs(result) do
	-- 		result[vertex] = value / maxtotal
	-- 	end
	-- end

	return result, eccentricities, radius, diameter
end

if arg then
	local test = Graph.new()
	test:addVertex(1)
	test:addVertex(2)
	test:addVertex(3)
	test:addVertex(4)

	test:addEdge({}, 1, 2)
	test:addEdge({}, 1, 3)
	test:addEdge({}, 1, 4)

	local path = test:allPairsShortestPaths()

	for i, weights in pairs(path) do
		for j, distance in pairs(weights) do
			print(i, j, distance)
		end
	end

	print()

	local betweenness = test:betweenness()

	for vertex, centrality in pairs(betweenness) do
		print(vertex, centrality)
	end
end











