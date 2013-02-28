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

	-- Only start rules can have one vertex in the pattern.
	local start = false

	if table.count(pattern.vertices) == 1 then
		local patternVertex = next(pattern.vertices)
		assert(patternVertex.tag == 's')

		start = true
	end

	-- No substitute rule can have start vertices ('s' tag).
	for substituteVertex, _ in pairs(substitute.vertices) do
		assert(substituteVertex.tag ~= 's')
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
	-- we don't create too many vertices.
	local delta = table.count(substitute.vertices) - table.count(pattern.vertices)
	assert(delta >= 0)

	local spurs = graph2D.spurs(pattern)

	local result = {
		pattern = pattern,
		substitute = substitute,
		map = map,
		delta = delta,
		start = start,
		spurs = spurs,
	}

	setmetatable(result, GraphGrammar.Rule)

	return result
end

local function _vertexEq( host, hostVertex, pattern, patterVertex )
	-- TODO: lock should probably be called valenceLock or something.
	if patterVertex.lock then
		if pattern.valences[patterVertex] ~= host.valences[hostVertex] then
			return false
		end
	end

	return hostVertex.tag == patterVertex.tag
end

function GraphGrammar.Rule:matches( graph )
	-- TODO: Probably need an edgeEq as well..
	local start = love.timer.getMicroTime()
	local success, result = graph:matches(self.pattern, _vertexEq)
	local finish = love.timer.getMicroTime()
	printf('    subgraph:%.4fs', finish-start)

	-- If we have some matches we need to apply some more checks and reject
	-- those which will cause us issues:
	-- - We check the signed angles between edges to ensure we don't allow
	--   'flipped' matches though. For example a triangle graph:
	--
	--   a - a
	--     \ |
	--       a
	--
	--   Can be matches to another trangle in the host graph in six ways. Three
	--   of the matches are rotations but the other three are 'flipped' (in
	--   geometric terms mirrored). These cause the re-established
	--   neighbourhood edges to intersect.
	--
	-- - TODO: need to add blocked neighbours checking.
	if success then
		local start = love.timer.getMicroTime()
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

			-- Now we check that the signs of the signed angles match. See 
			-- comment above about flipped matches to see why.

			local success = true

			for patternVertex, spur in pairs(self.spurs) do
				for _, patternEdgePair in ipairs(spur) do
					local patternEdge1 = patternEdgePair.edge1
					local patternEdge2 = patternEdgePair.edge2
					local patternSignedAngle = patternEdgePair.signedAngle

					local graphVertex = match[patternVertex]
					
					local graphEdge1EndVerts = graph.edges[edgeMap[patternEdge1]]
					local graphEdge1End = graphEdge1EndVerts[1]
					if graphEdge1End == graphVertex then
						graphEdge1End = graphEdge1EndVerts[2]
					end
					
					local graphEdge2EndVerts = graph.edges[edgeMap[patternEdge2]]
					local graphEdge2End = graphEdge2EndVerts[1]
					if graphEdge2End == graphVertex then
						graphEdge2End = graphEdge2EndVerts[2]
					end

					local to1 = Vector.to(graphVertex, graphEdge1End)
					local to2 = Vector.to(graphVertex, graphEdge2End)

					local graphSignedAngle = to1:signedAngle(to2)

					local sameSigns = math.sign(patternSignedAngle) == math.sign(graphSignedAngle)
					-- print('[signed]', math.deg(patternSignedAngle), math.deg(graphSignedAngle), sameSigns)

					if not sameSigns then
						success = false
						break
					end

				end

				if not success then
					break
				end
			end

			if not success then
				result[index] = result[#result]
				result[#result] = nil
			end
		end

		local finish = love.timer.getMicroTime()
		printf('    orient:%.4fs', finish-start)

		if #result == 0 then
			return false
		end
	end

	return success, result
end

-- Match should be one of the members of a result array from the matches()
-- method. If not, all bets are off and you better know what you're doing.
function GraphGrammar.Rule:replace( graph, match, params )
	local start = love.timer.getMicroTime()

	-- We need the inverse of the matching map.
	local inverseMatch = {}
	for patternVertex, graphVertex in pairs(match) do
		inverseMatch[graphVertex] = patternVertex
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

	-- Now we remove the matched vertices from the graph, while we're at it
	-- stash the postions of the removed vertices for when they're replaced by
	-- substitute vertices.
	local substitutePositions = {}
	local map = self.map
	for patternVertex, graphVertex in pairs(match) do
		substitutePositions[map[patternVertex]] = Vector.new(graphVertex)
		graph:removeVertex(graphVertex)
	end

	-- Add the, initially unconnected, substitute graph vertices.
	local substitute = self.substitute
	local substituteAABB = graph2D.aabb(substitute)
	-- We make copies of the substitute vertices so we need a map from
	-- subsitute vertices to their copies. 
	local vertexClones = {}
	local cloneVertex = params.cloneVertex
	for substituteVertex, _ in pairs(substitute.vertices) do
		local clone = cloneVertex(substituteVertex)

		-- If the substitute vertex is replacing a pattern vertex
		-- just use the already calculated position.
		local position = substitutePositions[substituteVertex]
		local projected = false
		if position then
			clone[1], clone[2] = position[1], position[2]
		else
			-- The substitute vertex is not replacing a current graph vertex
			-- so we need to create the position.

			if self.start then
				-- For start rules we can just map the position from substitute
				-- to graph space.
				local coord = substituteAABB:lerpTo(substituteVertex, matchAABB)
				-- NaN checks.
				assert(coord[1] == coord[1])
				assert(coord[2] == coord[2])
				clone[1], clone[2] = coord[1], coord[2]
			else
				-- For non-start rules we must take rotation into account.
				-- Luckily all non-start rules must have at least one edge in
				-- the pattern graph so we can use the edge to orient
				-- ourselves.

				-- TODO: this doesn't work properly :^(

				local patternEdge, patternEndVerts = next(self.pattern.edges)
				assert(patternEdge)

				local substituteOrigin = Vector.new(map[patternEndVerts[1]])
				local substituteBasisX = Vector.to(substituteOrigin, map[patternEndVerts[2]])
				substituteBasisX:normalise()
				local substituteBasisY = substituteBasisX:perp()
				
				local relSubstitutePos = Vector.to(substituteOrigin, substituteVertex)
				local xProj = substituteBasisX:dot(relSubstitutePos)
				local yProj = substituteBasisY:dot(relSubstitutePos)

				local graphOrigin = Vector.new(match[patternEndVerts[1]])
				local graphBasisXDir = Vector.to(graphOrigin, match[patternEndVerts[2]])
				local graphBasisX = graphBasisXDir:normal()
				local graphBasisY = graphBasisX:perp()

				graphBasisX:scale(xProj)
				graphBasisY:scale(yProj)

				local coord = Vector.new {
					graphOrigin[1] + graphBasisX[1] + graphBasisY[1],
					graphOrigin[2] + graphBasisX[2] + graphBasisY[2],
				}

				projected = true

				if params.replaceYield then
					local x11, y11 = graphOrigin[1], graphOrigin[2]
					local x12, y12 = x11 + graphBasisXDir[1], y11 + graphBasisXDir[2]

					local x21, y21 = graphOrigin[1], graphOrigin[2]
					local x22, y22 = x21 + graphBasisX[1], y21 + graphBasisX[2]

					local x31, y31 = graphOrigin[1], graphOrigin[2]
					local x32, y32 = x31 + graphBasisY[1], y31 + graphBasisY[2]

					local x41, y41 = graphOrigin[1], graphOrigin[2]
					local x42, y42 = coord[1], coord[2]

					while not gProgress do
						love.graphics.setLineWidth(5)
						
						love.graphics.setColor(255, 0, 255, 255)
						love.graphics.line(x11, y11, x12, y12)
						
						love.graphics.setLineWidth(3)
						
						love.graphics.setColor(255, 0, 0, 255)
						love.graphics.line(x21, y21, x22, y22)
						
						love.graphics.setColor(0, 0, 255, 255)
						love.graphics.line(x31, y31, x32, y32)

						love.graphics.setColor(255, 255, 255, 255)
						love.graphics.line(x41, y41, x42, y42)
						coroutine.yield(graph)
					end
					gProgress = false
				end

				-- -- NaN checks.
				-- assert(coord[1] == coord[1])
				-- assert(coord[2] == coord[2])
				clone[1], clone[2] = coord[1], coord[2]
			end
		end

		vertexClones[substituteVertex] = clone
		graph:addVertex(clone)

		if params.replaceYield and projected then
			while not gProgress do
				coroutine.yield(graph)
			end
			gProgress = false
		end
	end

	-- Now the substitute edges.
	-- { [substitute.edge] = fresh copy of the edge }
	local cloneEdge = params.cloneEdge
	for substituteEdge, substituteEdgeEnds in pairs(substitute.edges) do
		local clone = cloneEdge(substituteEdge)
		local substituteVertex1, substituteVertex2 = substituteEdgeEnds[1], substituteEdgeEnds[2]
		graph:addEdge(clone, vertexClones[substituteVertex1], vertexClones[substituteVertex2])
	end

	-- Now the dangling edges.
	for patternVertex, dangles in pairs(danglers) do
		for _, graphVertex in ipairs(dangles) do
			local embeddedVertex = vertexClones[map[patternVertex]]

			-- TODO: Need to copy edge properties or something.
			graph:addEdge({}, embeddedVertex, graphVertex)
		end
	end

	if params.replaceYield then
		while not gProgress do
			love.graphics.setLine(3, 'rough')
			love.graphics.setColor(0, 0, 255, 255)
			love.graphics.rectangle('line', matchAABB.xmin, matchAABB.ymin, matchAABB:width(), matchAABB:height())
			coroutine.yield(graph)
		end
		gProgress = false
	end

	local finish = love.timer.getMicroTime()
	printf('    replace:%.4fs', finish-start)

	-- Now make it pretty.
	local springStrength = params.springStrength
	local edgeLength = params.edgeLength
	local repulsion = params.repulsion
	local maxDelta = params.maxDelta
	local convergenceDistance = params.convergenceDistance
	local yield = params.drawYield
	graph2D.forceDraw(graph, springStrength, edgeLength, repulsion, maxDelta, convergenceDistance, yield)
end

-- TODO: this is only used on substitute vertices, rename to highlight that.
local function _defaultCloneVertex( vertex )
	return {
		vertex[1],
		vertex[2],
		tag = vertex.tag
	}
end

-- TODO: this is only used on substitute edges, rename to highlight that.
local function _defaultCloneEdge( edge )
	return {}
end

function GraphGrammar.new( params )
	local rules = params.rules
	local cloneVertex = params.cloneVertex or _defaultCloneVertex
	local cloneEdge = params.cloneEdge or _defaultCloneEdge

	local springStrength = params.springStrength or 1
	local edgeLength = params.edgeLength or 50
	local repulsion = params.repulsion or 1
	local maxDelta = params.maxDelta or 1
	local convergenceDistance = params.convergenceDistance or 2
	local drawYield = params.drawYield or false
	local replaceYield = params.replaceYield or false

	local numStartRules = 0

	for name, rule in pairs(rules) do
		if rule.start then
			numStartRules = numStartRules + 1
		end
	end

	assert(numStartRules > 0)

	local result = {
		rules = rules,
		cloneVertex = cloneVertex,
		cloneEdge = cloneEdge,
		
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

function GraphGrammar:build( maxIterations, minVertices, maxVertices )
	assert(0 < minVertices)
	assert(minVertices <= maxVertices)
	assert(math.floor(minVertices) == minVertices)
	assert(math.floor(maxVertices) == maxVertices)

	local graph = Graph.new()
	graph:addVertex { 0, 0, tag = 's' }
	local numVertices = 1

	local rules = self.rules
	local totalTime = 0

	for iteration = 1, maxIterations do
		local start = love.timer.getMicroTime()
		-- local f = fopen(string.format('graph-%03d.dot', iteration), 'w')
		
		local rulesMatches = {}

		printf('#%d', iteration)

		for name, rule in pairs(rules) do
			if numVertices + rule.delta > maxVertices then
				printf('  %s would pop vertex count', name)
			else
				local success, matches = rule:matches(graph)

				if success then
					rulesMatches[#rulesMatches+1] = {
						name = name,
						rule = rule,
						matches = matches
					}
				end

				printf('  %s #%d', name, not success and 0 or #matches)
			end
		end

		-- If we have zero matches then we cannot progress. Another iteration
		-- has no chance of getting more matches.
		local stalled = #rulesMatches == 0
		local enoughVertices = numVertices >= minVertices

		if stalled then
			if not enoughVertices then
				error('bulidng has stalled without enough vertices')
			end
		else
			local ruleMatch = rulesMatches[math.random(1, #rulesMatches)]

			printf('  %s', ruleMatch.name)

			local match = ruleMatch.matches[math.random(1, #ruleMatch.matches)]

			if self.replaceYield then
				while not gProgress do
					coroutine.yield(graph)
				end
				gProgress = false
			end

			ruleMatch.rule:replace(graph, match, self)

			numVertices = numVertices + ruleMatch.rule.delta
		end

		local finish = love.timer.getMicroTime()
		local delta = finish - start
		totalTime = totalTime + delta

		printf('  %.2fs', delta)

		if numVertices == maxVertices or (stalled and enoughVertices) then
			break
		end
	end

	printf('  total:%.2fs', totalTime)

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

	local maxIterations = 50
	local minVertices = 10
	local maxVertices = 20
	local result = grammar:build(maxIterations, minVertices, maxVertices)
end
