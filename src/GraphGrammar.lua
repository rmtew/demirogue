require 'Graph'

GraphGrammar = {
	Rule = {}
}

GraphGrammar.Rule.__index = GraphGrammar.Rule

-- TODO: Describe graph grammar production rules in a nice terse comment...
-- - All pattern and substitute vertices should have tag fields.

function GraphGrammar.Rule.new( pattern, substitute, map )
	-- Check that the pattern and substitute graphs have tags.
	for vertex, _ in pairs(pattern.vertices) do
		assert(vertex.tag)
	end

	for vertex, _ in pairs(substitute.vertices) do
		assert(vertex.tag)
	end

	-- Check that the map uses valid vertices.
	for patternVertex, substituteVertex in pairs(map) do
		assert(pattern.vertices[patternVertex])
		assert(substitute.vertices[substituteVertex])
	end

	-- Check that pattern is a subgraph of substitute using the map.
	for patternEdge, patternEdgeEnds in pairs(pattern.edges) do
		local patternVertex1, patternVertex2 = patternEdgeEnds[1], patternEdgeEnds[2]

		local substituteVertex1, substituteVertex2 = map[patternVertex1], map[patternVertex2]
		assert(substituteVertex1, substituteVertex2)

		local substituteEdge = substitute.vertices[substituteVertex1][substituteVertex2]
		assert(substituteEdge)
	end

	-- Find out which vertices are 'modified', i.e. have new edges.

	local result = {
		pattern = pattern,
		substitute = substitute,
		map = map,
	}

	setmetatable(result, GraphGrammar.Rule)

	return result
end

local function _vertexEq( host, hostVertex, pattern, patterVertex )
	return hostVertex.tag == patterVertex.tag
end

function GraphGrammar.Rule:matches( graph )
	-- TODO: Need a tag restriction vertexEq and edgeEq predicates.
	local success, result = graph:matches(self.pattern, _vertexEq)

	return success, result
end

-- Match should be one of the members of a result array from the matches()
-- method. If not all bets are off and you better know what you're doing.
function GraphGrammar.Rule:replace( graph, match )



end