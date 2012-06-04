--
-- Graph.lua
--
-- An incidence list based data structure.
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

	return result
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




