require 'Graph'

GraphGrammar = {
	Rule = {}
}

GraphGrammar.__index = GraphGrammar
GraphGrammar.Rule.__index = GraphGrammar.Rule

-- TODO: Describe graph grammar production rules in a nice terse comment...
-- - The pattern and substitute graphs should be non-empty and connected.
-- - All pattern and substitute vertices should have tag fields.
-- - Because there may be more than one way to replace the pattern with the
--   substitute, a map from pattern to substitute vertices has to be provided.
--   NOTE: this is used to reconnect dangling edges caused by the the removal
--         of the pattern subgraph.

function GraphGrammar.Rule.new( pattern, substitute, map )
	assert(not pattern:isEmpty())
	assert(not substitute:isEmpty())
	assert(pattern:isConnected())
	assert(substitute:isConnected())

	-- Check that the pattern and substitute graphs have tags.
	for vertex, _ in pairs(pattern.vertices) do
		assert(vertex.tag)
	end

	for vertex, _ in pairs(substitute.vertices) do
		assert(vertex.tag)
	end

	-- Check that the map uses valid vertices and is bijective.
	local inverse = {}
	for patternVertex, substituteVertex in pairs(map) do
		assert(pattern.vertices[patternVertex])
		assert(substitute.vertices[substituteVertex])

		assert(not inverse[substituteVertex])
		inverse[substituteVertex] = patternVertex
	end

	-- All pattern vertices should be mapped.
	-- NOTE: If I changed this check and replaced it with 'at least one pattern
	--       vertex must be mapped' it should still create connected graphs.
	--       The map is really used for determining where and when to reconnect
	--       dangling edges left by the removal of the pattern subgraph.
	assert(table.count(pattern.vertices) == table.count(map))

	-- TODO:
	-- Maybe the 'modified vertex has exact valence' rule.
	-- Find out which vertices are 'modified', i.e. have increased valence.
	
	-- How many new vertices would be added by this rule. Useful for ensuring
	-- we don;t create too many vertices.
	local delta = table.count(substitute.vertices) - table.count(pattern.vertices)
	assert(delta >= 0)

	local result = {
		pattern = pattern,
		substitute = substitute,
		map = map,
		delta = delta,
	}

	setmetatable(result, GraphGrammar.Rule)

	return result
end

local function _vertexEq( host, hostVertex, pattern, patterVertex )
	return hostVertex.tag == patterVertex.tag
end

function GraphGrammar.Rule:matches( graph )
	-- TODO: Probably need an edgeEq as well..
	local success, result = graph:matches(self.pattern, _vertexEq)

	return success, result
end

-- Match should be one of the members of a result array from the matches()
-- method. If not, all bets are off and you better know what you're doing.
--
-- TODO: May need a specific vertex copy function.
function GraphGrammar.Rule:replace( graph, match )
	-- We need the inverse of the matching map.
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
	-- { [substitute.vertex] = fresh copy of the vertex }
	local vertexEmbedding = {}
	for substituteVertex, _ in pairs(substitute.vertices) do
		local copy = table.copy(substituteVertex)
		vertexEmbedding[substituteVertex] = copy
		graph:addVertex(copy)
	end

	-- Now the substitute edges.
	local edgeEmbedding = {}
	-- { [substitute.edge] = fresh copy of the edge }
	for substituteEdge, substituteEdgeEnds in pairs(substitute.edges) do
		-- TODO: this feels a bit dirty...
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

	-- TODO:
	-- - Check we have at least one start rule.
	--   - One start tagged vertex in the pattern graph.
	--   - No start tagged vertices in any substitute graphs.

	local result = {
		rules = rules,
		graph = nil,
	}

	setmetatable(result, GraphGrammar)

	return result
end

-- TODO: Need to maintain a generator DAG.
function GraphGrammar:build( maxIterations, maxVertices )
	local graph = Graph.new()
	graph:addVertex { tag = 'start' }

	local rules = self.rules

	for iteration = 1, maxIterations do

		local f = fopen(string.format('graph-%03d.dot', iteration), 'w')
		
		local rulesMatches = {}

		printf('#%d', iteration)

		for name, rule in pairs(rules) do
			local success, result = rule:matches(graph)

			if success then
				rulesMatches[#rulesMatches+1] = {
					name = name,
					rule = rule,
					matches = result
				}
			end

			printf('  %s #%d', name, not success and 0 or #result)
		end

		-- If this is ever 0 it means the building process has stalled.
		assert(#rulesMatches > 0)

		local ruleMatch = rulesMatches[math.random(1, #rulesMatches)]

		printf('  %s', ruleMatch.name)

		local match = ruleMatch.matches[math.random(1, #ruleMatch.matches)]

		ruleMatch.rule:replace(graph, match)

		local dotFile = graph:dotFile('G' .. iteration, function ( vertex ) return vertex.tag end)

		f:write(dotFile)

		f:close()
	end

	return graph
end


if arg then
	-- local pattern = Graph.new()
	-- local start = { tag = 'start' }
	-- pattern:addVertex(start)

	-- local substitute = Graph.new()
	-- local a = { tag = 'a' }
	-- local b = { tag = 'b' }

	-- substitute:addVertex(a)
	-- substitute:addVertex(b)
	-- substitute:addEdge({}, a, b)

	-- local rule1 = GraphGrammar.Rule.new(pattern, substitute, { [start] = a })

	-- local pattern2 = Graph.new()
	-- pattern2:addVertex(a)
	-- pattern2:addVertex(b)
	-- pattern2:addEdge({}, a, b)

	-- local substitute2 = Graph.new()
	-- local c = { tag = 'c' }
	-- substitute2:addVertex(a)
	-- substitute2:addVertex(b)
	-- substitute2:addVertex(c)
	-- substitute2:addEdge({}, a, b)
	-- substitute2:addEdge({}, b, c)

	-- local rule2 = GraphGrammar.Rule.new(pattern2, substitute2, { [a] = a, [b] = b })

	-- local pattern3 = Graph.new()
	-- pattern3:addVertex(b)
	-- pattern3:addVertex(c)
	-- local c2 = { tag = 'c' }
	-- pattern3:addVertex(c2)
	-- pattern3:addEdge({}, b, c)
	-- pattern3:addEdge({}, b, c2)

	-- local substitute3 = Graph.new()
	-- local d = { tag = 'd' }
	-- substitute3:addVertex(a)
	-- substitute3:addVertex(b)
	-- substitute3:addVertex(c)
	-- substitute3:addVertex(d)

	-- substitute3:addEdge({}, a, b)
	-- substitute3:addEdge({}, a, c)
	-- substitute3:addEdge({}, b, d)
	-- substitute3:addEdge({}, c, d)

	-- local rule3 = GraphGrammar.Rule.new(pattern3, substitute3, { [b] = a, [c] = b, [c2] = c })

	-- local grammar = GraphGrammar.new {
	-- 	rules = {
	-- 		rule1 = rule1,
	-- 		rule2 = rule2,
	-- 		rule3 = rule3,
	-- 	}
	-- }

	-- local result = grammar:build(50, 5)

	local pattern1 = Graph.new()
	local start = { tag = 'start' }
	pattern1:addVertex(start)

	--     p
	--   / | \
	-- p - a - p
	--   \ | /
	--     p

	local substitute1 = Graph.new()
	local abyss = { tag = 'abyss' }
	local p1 = { tag = 'p' }
	local p2 = { tag = 'p' }
	local p3 = { tag = 'p' }
	local p4 = { tag = 'p' }

	substitute1:addVertex(abyss)
	substitute1:addVertex(p1)
	substitute1:addVertex(p2)
	substitute1:addVertex(p3)
	substitute1:addVertex(p4)

	substitute1:addEdge({}, abyss, p1)
	substitute1:addEdge({}, abyss, p2)
	substitute1:addEdge({}, abyss, p3)
	substitute1:addEdge({}, abyss, p4)
	substitute1:addEdge({}, p1, p2)
	substitute1:addEdge({}, p2, p3)
	substitute1:addEdge({}, p3, p4)
	substitute1:addEdge({}, p4, p1)

	local init = GraphGrammar.Rule.new(pattern1, substitute1, { [start] = abyss })

	--     p
	--   / |
	-- p - a
	local pattern2 = Graph.new()
	local pabyss = { tag = 'abyss' }
	local pp1 = { tag = 'p' }
	local pp2 = { tag = 'p' }
	
	pattern2:addVertex(pabyss)
	pattern2:addVertex(pp1)
	pattern2:addVertex(pp2)
	
	pattern2:addEdge({}, pabyss, pp1)
	pattern2:addEdge({}, pabyss, pp2)
	pattern2:addEdge({}, pp1, pp2)

	--     p
	--   / | \
	-- p - a - p
	local substitute2 = Graph.new()
	local sabyss = { tag = 'abyss' }
	local sp1 = { tag = 'p' }
	local sp2 = { tag = 'p' }
	local sp3 = { tag = 'p' }
	
	substitute2:addVertex(sabyss)
	substitute2:addVertex(sp1)
	substitute2:addVertex(sp2)
	substitute2:addVertex(sp3)
	
	substitute2:addEdge({}, sabyss, sp1)
	substitute2:addEdge({}, sabyss, sp2)
	substitute2:addEdge({}, sabyss, sp3)
	substitute2:addEdge({}, sp1, sp3)
	substitute2:addEdge({}, sp2, sp3)

	local map = {
		[pabyss] = sabyss,
		[pp1] = sp1,
		[pp2] = sp2,
	}

	local subdiv = GraphGrammar.Rule.new(pattern2, substitute2, map)

	--     p
	--   / |
	-- p - a
	local pattern3 = Graph.new()
	local pabyss = { tag = 'abyss' }
	local pp1 = { tag = 'p' }
	local pp2 = { tag = 'p' }
	
	pattern3:addVertex(pabyss)
	pattern3:addVertex(pp1)
	pattern3:addVertex(pp2)
	
	pattern3:addEdge({}, pabyss, pp1)
	pattern3:addEdge({}, pabyss, pp2)
	pattern3:addEdge({}, pp1, pp2)

	-- c - p
	--   / | 
	-- p - a 
	local substitute3 = Graph.new()
	local sabyss = { tag = 'abyss' }
	local sp1 = { tag = 'p' }
	local sp2 = { tag = 'p' }
	local sc = { tag = 'c' }
	
	substitute3:addVertex(sabyss)
	substitute3:addVertex(sp1)
	substitute3:addVertex(sp2)
	substitute3:addVertex(sc)
	
	substitute3:addEdge({}, sabyss, sp1)
	substitute3:addEdge({}, sabyss, sp2)
	substitute3:addEdge({}, sp1, sp2)
	substitute3:addEdge({}, sp1, sc)

	local map = {
		[pabyss] = sabyss,
		[pp1] = sp1,
		[pp2] = sp2,
	}

	local crypt = GraphGrammar.Rule.new(pattern3, substitute3, map)

	local grammar = GraphGrammar.new {
		rules = {
			init = init,
			subdiv = subdiv,
			crypt = crypt,
		}
	}

	local result = grammar:build(50, 20)
end
