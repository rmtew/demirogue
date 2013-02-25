require 'Graph'
require 'graph2D'

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
		assert(type(vertex[1]) == 'number' and math.floor(vertex[1]) == vertex[1])
		assert(vertex[1] == vertex[1])
		assert(type(vertex[2]) == 'number' and math.floor(vertex[2]) == vertex[2])
		assert(vertex[2] == vertex[2])
	end

	for vertex, _ in pairs(substitute.vertices) do
		assert(vertex.tag)
		assert(type(vertex[1]) == 'number' and math.floor(vertex[1]) == vertex[1])
		assert(vertex[1] == vertex[1])
		assert(type(vertex[2]) == 'number' and math.floor(vertex[2]) == vertex[2])
		assert(vertex[2] == vertex[2])
	end

	-- Check that the map uses valid vertices and is bijective.
	local inverse = {}
	for patternVertex, substituteVertex in pairs(map) do
		assert(pattern.vertices[patternVertex])
		assert(substitute.vertices[substituteVertex])

		assert(not inverse[substituteVertex])
		inverse[substituteVertex] = patternVertex
	end

	-- Now we create the edge winding order lists.
	local windings = {}
	for patternVertex1, patternPeers in pairs(pattern.vertices) do
		local winding = {}

		for patternVertex2, patternEdge in pairs(patternPeers) do
			local to = Vector.to(patternVertex1, patternVertex2)
			local angle = math.atan2(to[2], to[1])
			winding[#winding+1] = { angle = angle, edge = patternEdge }
		end

		table.sort(winding,
				function ( lhs, rhs )
					return lhs.angle < rhs.angle
				end)

		-- Don't need the angles, just the edges in order.
		for index = 1, #winding do
			winding[index] = winding[index].edge
		end

		windings[patternVertex1] = winding
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

	-- Useful in replace().
	local inverseMap = {}
	for patterVertex, substituteVertex in pairs(map) do
		inverseMap[substituteVertex] = patternVertex
	end

	local result = {
		pattern = pattern,
		substitute = substitute,
		map = map,
		inverseMap = inverseMap,
		windings = windings,
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

	-- The following bit of code is flawed...
	if success and false then
		-- Iterate backwards because we may be removing matches.
		for index = #result, 1, -1 do
			local match = result[index]
			
			-- First off we need a map from pattern edges to host edges.
			local edgeMap = {}

			for patternEdge, patternEndVerts in pairs(self.pattern.edges) do
				local graphVertex1 = match[patternEndVerts[1]]
				local graphVertex2 = match[patternEndVerts[2]]
				edgeMap[patternEdge] = graph.vertices[graphVertex1][graphVertex2]
			end

			-- Now calculate the windings for the host graph.
			for patternVertex1, patternPeers in pairs(self.pattern.vertices) do
				local graphVertex1 = match[patternVertex1]

				local graphWinding = {}

				for patternVertex2, patternEdge in pairs(patternPeers) do
					local graphVertex2 = match[patternVertex2]
					local to = Vector.to(graphVertex1, graphVertex2)
					local angle = math.atan2(to[2], to[1])
					graphWinding[#graphWinding+1] = {
						angle = angle,
						edge = edgeMap[patternEdge]
					}
				end

				table.sort(graphWinding,
						function ( lhs, rhs )
							return lhs.angle < rhs.angle
						end)

				-- Check that the edges in the host and the pattern have the
				-- same winding order.
				local winding = self.windings[patternVertex1]
				local success = true

				print('#WINDING', #winding)

				for i = 1, #graphWinding-1 do
					local graphEdge1 = graphWinding[i]
					local graphEdge2 = graphWinding[i+1]

					for j, patternEdge in ipairs(winding) do
						if edgeMap[patternEdge] == graphEdge1 then
							local nj = (j == #winding) and 1 or j + 1

							if graphEdge2 ~= edgeMap[winding[nj]] then
								print('WIND FAIL')
								success = false
								break
							end
						end
					end

					if not success then
						break
					end
				end

				if not success then
					matches[index] = matches[#matches]
					matches[#matches] = nil
				end
			end
		end

		if #result == 0 then
			return false
		end
	end

	return success, result
end

-- Match should be one of the members of a result array from the matches()
-- method. If not, all bets are off and you better know what you're doing.
--
-- TODO: May need a specific vertex copy function.
function GraphGrammar.Rule:replace( graph, match, params )
	-- We need the inverse of the matching map.
	local inverseMatch = {}
	for patternVertex, graphVertex in pairs(match) do
		inverseMatch[graphVertex] = patternVertex
		print(patternVertex[1], patternVertex[2], graphVertex[1], graphVertex[2])
	end

	local matchAABB = graph2D.matchAABB(match)

	-- If the AABB of the matched part of the host graph is too small enlarge.
	if matchAABB:width() < 1 then
		local fudge = 0.5
		matchAABB.xmin = matchAABB.xmin - fudge
		matchAABB.xmax = matchAABB.xmax + fudge
	end

	if matchAABB:height() < 1 then
		local fudge = 0.5
		matchAABB.ymin = matchAABB.ymin - fudge
		matchAABB.ymax = matchAABB.ymax + fudge
	end

	-- Shrink to a quarter of the size.
	-- matchAABB:scale(0.95)

	-- First off let's find out which edges we'll need to re-establish.
	-- { [patternVertex] = { graphVertex }* }
	local danglers = {}
	for patternVertex, graphVertex in pairs(match) do
		local dangles = {}

		for graphPeer, graphEdge in pairs(graph.vertices[graphVertex]) do
			-- If a graph vertex has a peer that isn't in the match we'll need
			-- to reconnect it later.
			if not inverseMatch[graphPeer] then
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
	local substituteAABB = graph2D.aabb(substitute)
	-- { [substitute.vertex] = fresh copy of the vertex }
	local vertexEmbedding = {}
	local inverseMap = self.inverseMap
	for substituteVertex, _ in pairs(substitute.vertices) do
		local copy = table.copy(substituteVertex)

		-- If the substitute vertex is replacing a pattern vertex
		-- just use the already calculated position.
		local inverse = inverseMap[substituteVertex]
		if inverse then
			local graphVertex = match[inverse]
			copy[1], copy[2] = graphVertex[1], graphVertex[2]
		else
			-- If this a new substitutw vertex lerp to position.
			-- TODO: need to rotate
			local coord = substituteAABB:lerpTo(substituteVertex, matchAABB)
			-- NaN checks.
			assert(coord[1] == coord[1])
			assert(coord[2] == coord[2])
			copy[1], copy[2] = coord[1], coord[2]
		end

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

	-- Now make it pretty.
	local springStrength = params.springStrength
	local edgeLength = params.edgeLength
	local repulsion = params.repulsion
	local maxDelta = params.maxDelta
	local convergenceDistance = params.convergenceDistance
	local yield = params.drawYield
	graph2D.forceDraw(graph, springStrength, edgeLength, repulsion, maxDelta, convergenceDistance, yield)
end

function GraphGrammar.new( params )
	local rules = params.rules

	local springStrength = params.springStrength or 1
	local edgeLength = params.edgeLength or 50
	local repulsion = params.repulsion or 1
	local maxDelta = params.maxDelta or 1
	local convergenceDistance = params.convergenceDistance or 2
	local drawYield = params.drawYield or false
	local replaceYield = params.replaceYield or false

	-- TODO:
	-- - Check we have at least one start rule.
	--   - One start tagged vertex in the pattern graph.
	--   - No start tagged vertices in any substitute graphs.

	local result = {
		rules = rules,
		graph = nil,
		springStrength = springStrength,
		edgeLength = edgeLength,
		repulsion = repulsion,
		maxDelta = maxDelta,
		convergenceDistance = convergenceDistance,
		drawYield = drawYield,
		replaceYield = replaceYield,
	}

	setmetatable(result, GraphGrammar)

	return result
end

-- TODO: Need to maintain a generator DAG.
function GraphGrammar:build( maxIterations, maxVertices )
	local graph = Graph.new()
	graph:addVertex { 400, 300, tag = 's' }

	local rules = self.rules

	for iteration = 1, maxIterations do
		-- local f = fopen(string.format('graph-%03d.dot', iteration), 'w')
		
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

		ruleMatch.rule:replace(graph, match, self)

		if self.replaceYield then
			coroutine.yield(graph)
		end

		-- local dotFile = graph:dotFile('G' .. iteration, function ( vertex ) return vertex.tag end)
		-- f:write(dotFile)
		-- f:close()
	end

	return graph
end

if arg and false then
	local pattern1 = Graph.new()
	local start = { 0, 0, tag = 's' }
	pattern1:addVertex(start)

	--     p
	--   / | \
	-- p - a - p
	--   \ | /
	--     p

	local substitute1 = Graph.new()
	local abyss = { 0, 0, tag = 'abyss' }
	local p1 = { 0, -1, tag = 'p' }
	local p2 = { 1, 0, tag = 'p' }
	local p3 = { 0, 1, tag = 'p' }
	local p4 = { -1, 0, tag = 'p' }

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
	local pabyss = { 0, 0, tag = 'abyss' }
	local pp1 = { 0, -1, tag = 'p' }
	local pp2 = { -1, 0, tag = 'p' }
	
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
	local sabyss = { 0, 0, tag = 'abyss' }
	local sp1 = { -1, 0, tag = 'p' }
	local sp2 = { 1, 0, tag = 'p' }
	local sp3 = { 0, -1, tag = 'p' }
	
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
	local pabyss = { 0, 0, tag = 'abyss' }
	local pp1 = { 0, -1, tag = 'p' }
	local pp2 = { -1, 0, tag = 'p' }
	
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
	local sabyss = { 0, 0, tag = 'abyss' }
	local sp1 = { 0, -1, tag = 'p' }
	local sp2 = { -1, 0, tag = 'p' }
	local sc = { -1, -1, tag = 'c' }
	
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
