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



