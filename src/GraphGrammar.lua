require 'Graph'

GraphGrammar = {
	Rule = {}
}

GraphGrammar.__index = GraphGrammar
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

	-- Check that the map uses valid vertices and is a bijection.
	local inverse = {}
	for patternVertex, substituteVertex in pairs(map) do
		assert(pattern.vertices[patternVertex])
		assert(substitute.vertices[substituteVertex])

		assert(not inverse[substituteVertex])
		inverse[substituteVertex] = patternVertex
	end

	-- All pattern vertices should be mapped.
	assert(table.count(pattern.vertices) == table.count(map))

	-- TODO:
	-- Check that pattern and substitute are connected.
	-- Maybe the 'modified vertex has exact valence' rule.
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
--
-- May need a specific vertex copy function.
function GraphGrammar.Rule:replace( graph, match )
	local inverse = {}

	for patternVertex, graphVertex in pairs(match) do
		inverse[graphVertex] = patternVertex
	end

	-- First off let's find out which edges we'll need to re-establish.
	-- { [patternVertex] = { graphVertex }* }
	local danglers = {}
	for patternVertex, graphVertex in pairs(match) do
		local dangles = {}

		for graphPeer, graphEdge in pairs(graph.vertices[graphVertex]) do
			-- If a graph vertex has a peer that isn't in the match we'll need
			-- to reconnect it later.
			if not inverse[graphPeer] then
				dangles[#dangles+1] = graphPeer
			end
		end

		danglers[patternVertex] = dangles
	end

	-- Now we remove the matched vertices from the graph.
	for patternVertex, graphVertex in pairs(match) do
		graph:removeVertex(graphVertex)
	end

	-- Add the, initially unconnected, substitute graph vertices.
	local substitute = self.substitute
	local vertexEmbedding = {}
	for substituteVertex, _ in pairs(substitute.vertices) do
		local copy = table.copy(substituteVertex)
		vertexEmbedding[substituteVertex] = copy
		graph:addVertex(copy)
	end

	-- Now the substitute edges.
	local edgeEmbedding = {}
	for substituteEdge, substituteEdgeEnds in pairs(substitute.edges) do
		local copy = table.copy(substituteEdge)
		edgeEmbedding[substituteEdge] = copy
		local substituteVertex1, substituteVertex2 = substituteEdgeEnds[1], substituteEdgeEnds[2]
		graph:addEdge(copy, vertexEmbedding[substituteVertex1], vertexEmbedding[substituteVertex2])
	end

	-- Now the dangling edges.
	local map = self.map

	for patternVertex, dangles in pairs(danglers) do
		for _, graphVertex in ipairs(dangles) do
			local embeddedVertex = vertexEmbedding[map[patternVertex]]

			-- TODO: Need to copy edge properties or something.
			graph:addEdge({}, embeddedVertex, graphVertex)
		end
	end
end

function GraphGrammar.new( params )
	local rules = params.rules

	local result = {
		rules = rules,
		graph = nil,
	}

	setmetatable(result, GraphGrammar)

	return result
end

function GraphGrammar:build( maxIterations, maxVertices )
	local graph = Graph.new()

	graph:addVertex { tag = 'start' }

	local rules = self.rules

	for iteration = 1, maxIterations do

		local f = fopen(string.format('dots/graph-%03d.dot', iteration), 'w')
		
		local rulesMatches = {}

		printf('#%d', iteration)

		for name, rule in pairs(rules) do
			local success, result = rule:matches(graph)

			if success then
				rulesMatches[#rulesMatches+1] = { rule = rule, matches = result }
			end

			printf('  %s #%d', name, not success and 0 or #result)
		end

		assert(#rulesMatches > 0)

		local ruleMatch = rulesMatches[math.random(1, #rulesMatches)]

		local match = ruleMatch.matches[math.random(1, #ruleMatch.matches)]

		ruleMatch.rule:replace(graph, match)

		local dotFile = graph:dotFile('G' .. iteration, function ( vertex ) return vertex.tag end)

		f:write(dotFile)

		f:close()
	end

	return graph
end


if arg then
	local pattern = Graph.new()
	local start = { tag = 'start' }
	pattern:addVertex(start)

	local substitute = Graph.new()
	local a = { tag = 'a' }
	local b = { tag = 'b' }

	substitute:addVertex(a)
	substitute:addVertex(b)
	substitute:addEdge({}, a, b)

	local rule1 = GraphGrammar.Rule.new(pattern, substitute, { [start] = a })

	local pattern2 = Graph.new()
	pattern2:addVertex(a)
	pattern2:addVertex(b)
	pattern2:addEdge({}, a, b)

	local substitute2 = Graph.new()
	local c = { tag = 'c' }
	substitute2:addVertex(a)
	substitute2:addVertex(b)
	substitute2:addVertex(c)
	substitute2:addEdge({}, a, b)
	substitute2:addEdge({}, b, c)

	local rule2 = GraphGrammar.Rule.new(pattern2, substitute2, { [a] = a, [b] = b })

	local pattern3 = Graph.new()
	pattern3:addVertex(b)
	pattern3:addVertex(c)
	local c2 = { tag = 'c' }
	pattern3:addVertex(c2)
	pattern3:addEdge({}, b, c)
	pattern3:addEdge({}, b, c2)

	local substitute3 = Graph.new()
	local d = { tag = 'd' }
	substitute3:addVertex(a)
	substitute3:addVertex(b)
	substitute3:addVertex(c)
	substitute3:addVertex(d)

	substitute3:addEdge({}, a, b)
	substitute3:addEdge({}, a, c)
	substitute3:addEdge({}, b, d)
	substitute3:addEdge({}, c, d)

	local rule3 = GraphGrammar.Rule.new(pattern3, substitute3, { [b] = a, [c] = b, [c2] = c })

	local grammar = GraphGrammar.new {
		rules = {
			rule1 = rule1,
			rule2 = rule2,
			rule3 = rule3,
		}
	}

	local result = grammar:build(20, 5)
end
