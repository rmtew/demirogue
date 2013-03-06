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

-- Used when checking the pattern and subtitute graphs are connected.
local function _edgeFilter( edge )
	return not edge.cosmetic
end

function GraphGrammar.Rule.new( pattern, substitute, map )
	assert(not pattern:isEmpty(), 'pattern graph is empty')
	assert(not substitute:isEmpty(), 'subsitute graph is empty')

	-- All vertices must be connected disregarding cosmetic edges.
	-- TODO: we may need the concept of cosmetic vertex...
	assert(pattern:isConnectedWithEdgeFilter(_edgeFilter), 'pattern is not connected')
	assert(substitute:isConnectedWithEdgeFilter(_edgeFilter), 'substitute is not connected')

	-- Check that the pattern and substitute graphs have tags.
	for vertex, _ in pairs(pattern.vertices) do
		assert(vertex.tags, 'no tags for pattern vertex')
		assert(type(vertex[1]) == 'number' and math.floor(vertex[1]) == vertex[1], 'pattern vertex has no X value')
		assert(vertex[1] == vertex[1], 'pattern vertex X value is NaN')
		assert(type(vertex[2]) == 'number' and math.floor(vertex[2]) == vertex[2], 'pattern vertex has no Y value')
		assert(vertex[2] == vertex[2], 'pattern vertex Y value is NaN')
	end

	for vertex, _ in pairs(substitute.vertices) do
		assert(vertex.tag, ' no tag for substitute vertex')
		assert(type(vertex[1]) == 'number' and math.floor(vertex[1]) == vertex[1], 'substitute vertex has no X value')
		assert(vertex[1] == vertex[1], 'substitute vertex X value is NaN')
		assert(type(vertex[2]) == 'number' and math.floor(vertex[2]) == vertex[2], 'substitute vertex has no X value')
		assert(vertex[2] == vertex[2], 'substitute vertex Y value is NaN')
	end

	-- Check that the map uses valid vertices and is bijective.
	local inverse = {}
	for patternVertex, substituteVertex in pairs(map) do
		assert(pattern.vertices[patternVertex], 'invalid map pattern vertex')
		assert(substitute.vertices[substituteVertex], 'invalid map substitute vertex')

		assert(not inverse[substituteVertex], 'map is not bijective')
		inverse[substituteVertex] = patternVertex
	end

	-- Only start rules can have one vertex in the pattern.
	local start = false

	if table.count(pattern.vertices) == 1 then
		local patternVertex = next(pattern.vertices)
		assert(table.count(patternVertex.tags) == 1, 'single vertex pattern needs a single s tag')
		assert(next(patternVertex.tags) == 's', 'single vertex pattern needs a single s tag')

		start = true
	end

	-- No pattern non-start pattern rule can have start vertices ('s' tag).
	if not start then
		for patternVertex, _ in pairs(pattern.vertices) do
			assert(not patternVertex.tags.s, 'non-start pattern has an s tag')
		end
	end

	-- No substitute rule can have start vertices ('s' tag).
	for substituteVertex, _ in pairs(substitute.vertices) do
		assert(substituteVertex.tag ~= 's', 'no s tag allowed in substitute')
	end

	-- All pattern vertices should be mapped.
	-- NOTE: If I changed this check and replaced it with 'at least one pattern
	--       vertex must be mapped' it should still create connected graphs.
	--       The map is really used for determining where and when to reconnect
	--       dangling edges left by the removal of the pattern subgraph.
	assert(table.count(pattern.vertices) == table.count(map), 'substitute has less vertices than the pattern')
	
	-- How many new vertices would be added by this rule. Useful for ensuring
	-- we don't create too many vertices.
	local vertexDelta = table.count(substitute.vertices) - table.count(pattern.vertices)
	assert(vertexDelta >= 0, 'substitute has less vertices than the pattern')

	-- How many edges are added (or removed) on mapped vertices by the
	-- application of this rule. This is used to ensure we don't exceed the
	-- maxValence specified when building.
	local valenceDeltas = {}

	for patternVertex, substituteVertex in pairs(map) do
		local patternValence = pattern.valences[patternVertex]
		local substituteValence = substitute.valences[substituteVertex]
		local valenceDelta = substituteValence - patternValence

		valenceDeltas[patternVertex] = valenceDelta
	end

	local spurs = graph2D.spurs(pattern)

	-- Which edges in the pattern are present in the substitute?
	-- { [substituteEdge] = patternEdge }
	local mappedEdges = {}

	for substituteEdge, _ in pairs(substitute.edges) do
		if substituteEdge.subdivide then
			local lengthFactor = substituteEdge.lengthFactor
			assert(type(lengthFactor) == 'number' and lengthFactor > 0)
		end
	end

	for patternEdge, patternEndVerts in pairs(pattern.edges) do
		local patternVertex1 = patternEndVerts[1]
		local patternVertex2 = patternEndVerts[2]
		local substituteEdge = pattern.vertices[patternVertex1][patternVertex2]

		if substituteEdge then
			mappedEdges[substituteEdge] = patternEdge
		end
	end

	local result = {
		pattern = pattern,
		substitute = substitute,
		map = map,
		vertexDelta = vertexDelta,
		valenceDeltas = valenceDeltas,
		start = start,
		spurs = spurs,
		mappedEdges = mappedEdges,
	}

	setmetatable(result, GraphGrammar.Rule)

	return result
end

local function _vertexEq( host, hostVertex, pattern, patternVertex )
	-- TODO: lock should probably be called valenceLock or something.
	if patternVertex.lock then
		if pattern.valences[patternVertex] ~= host.valences[hostVertex] then
			return false
		end
	end

	return patternVertex.tags[hostVertex.tag]
end

local function _edgeEq( host, hostEdge, pattern, patternEdge )
	return hostEdge.cosmetic == patternEdge.cosmetic
end

function GraphGrammar.Rule:matches( graph, maxValence )
	-- TODO: Probably need an edgeEq as well..
	local start = love.timer.getMicroTime()
	local success, result = graph:matches(self.pattern, _vertexEq, _edgeEq)
	local finish = love.timer.getMicroTime()
	printf('    subgraph:%.4fs', finish-start)

	-- If we have some matches we need to apply some more checks and reject
	-- those which will cause us issues:
	--
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
	-- - If the valence of a vertex gets too high the graph drawing will create
	--   a lot of intersecting edges. So we have a maxValence parameter and
	--   check to see if it would be exceeded by the application of the rule.
	--
	-- - TODO: need to add blocked neighbours checking.
	if success then
		local start = love.timer.getMicroTime()
		-- Iterate backwards because we may be removing matches.

		local numFlipFails = 0
		local numValenceFails = 0

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
						numFlipFails = numFlipFails + 1
						break
					end

				end

				if not success then
					break
				end
			end

			-- Check that we're not exceeding the maxValence constraint.
			for patternVertex, graphVertex in pairs(match) do
				local graphValence = graph.valences[graphVertex]
				local outputValence = graphValence + self.valenceDeltas[patternVertex]

				-- print('valence: ', graphValence, self.valenceDeltas[patternVertex], outputValence, maxValence, outputValence > maxValence)

				if outputValence > maxValence then
					numValenceFails = numValenceFails + 1
					success = false
				end
			end

			if not success then
				result[index] = result[#result]
				result[#result] = nil
			end
		end

		local finish = love.timer.getMicroTime()
		printf('    filter:%.4fs #flip:%d #:valence:%d', finish-start, numFlipFails, numValenceFails)

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

	-- Calculate the mean length of the matched edges.
	local totalHostEdgeLength = 0
	local numPatternVertices = 0
	-- { [patternEdge] = <number> }
	local hostLengthFactors = {}

	for patternEdge, patternEndVerts in pairs(self.pattern.edges) do
		local graphVertex1 = match[patternEndVerts[1]]
		local graphVertex2 = match[patternEndVerts[2]]
		assert(graphVertex1)
		assert(graphVertex2)

		local hostEdgeLength = Vector.toLength(graphVertex1, graphVertex2)

		totalHostEdgeLength = totalHostEdgeLength + hostEdgeLength
		numPatternVertices = numPatternVertices + 1

		local graphEdge = graph.vertices[graphVertex1][graphVertex2]
		hostLengthFactors[patternEdge] = graphEdge.lengthFactor
	end

	local meanHostEdgeLength = params.edgeLength
	if numPatternVertices > 0 then
		meanHostEdgeLength = totalHostEdgeLength / numPatternVertices
	end

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
	local cloneEdge = params.cloneEdge
	for patternVertex, graphVertex in pairs(match) do
		local dangles = {}

		for graphPeer, graphEdge in pairs(graph.vertices[graphVertex]) do
			-- If a graph vertex has a peer that isn't in the match we'll need
			-- to reconnect it later.
			if not inverseMatch[graphPeer] then
				dangles[#dangles+1] = {
					graphVertex = graphPeer,
					graphEdge = cloneEdge(graphEdge),
				}
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
	local insertions = {}
	local cloneVertex = params.cloneVertex
	for substituteVertex, _ in pairs(substitute.vertices) do
		local clone = cloneVertex(substituteVertex)

		-- If the substitute vertex is replacing a pattern vertex
		-- just use the already calculated position.
		local position = substitutePositions[substituteVertex]
		local projected = false
		local draw = nil
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

				local normedXProj = xProj / math.max(xProj, yProj)
				local normedYProj = yProj / math.max(xProj, yProj)

				normedXProj = normedXProj * meanHostEdgeLength
				normedYProj = normedYProj * meanHostEdgeLength

				-- graphBasisX:scale(xProj)
				-- graphBasisY:scale(yProj)

				graphBasisX:scale(normedXProj)
				graphBasisY:scale(normedYProj)

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
		insertions[clone] = true
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
	local mappedEdges = self.mappedEdges
	local edgeLength = params.edgeLength
	local meanHostEdgeLengthFactor = meanHostEdgeLength / edgeLength
	for substituteEdge, substituteEdgeEnds in pairs(substitute.edges) do
		local clone = cloneEdge(substituteEdge)

		local patternEdge = mappedEdges[substituteEdge]

		if patternEdge then
			clone.lengthFactor = hostLengthFactors[patternEdge]
			assert(clone.lengthFactor)
		elseif substituteEdge.subdivide then
			assert(clone.lengthFactor)

			printf('lf:%.2f => %.2f ', clone.lengthFactor, clone.lengthFactor * meanHostEdgeLengthFactor)
			printf('  mhelf:%.2f mhel:%.2f el:%.2f ', meanHostEdgeLengthFactor, meanHostEdgeLength, edgeLength)

			clone.lengthFactor = clone.lengthFactor * meanHostEdgeLengthFactor
		end

		local substituteVertex1, substituteVertex2 = substituteEdgeEnds[1], substituteEdgeEnds[2]
		graph:addEdge(clone, vertexClones[substituteVertex1], vertexClones[substituteVertex2])
	end

	-- Now the dangling edges.
	for patternVertex, dangles in pairs(danglers) do
		for _, graphVertexAndEdge in ipairs(dangles) do
			local embeddedVertex = vertexClones[map[patternVertex]]

			local graphVertex = graphVertexAndEdge.graphVertex
			local graphEdge = graphVertexAndEdge.graphEdge
			
			graph:addEdge(graphEdge, embeddedVertex, graphVertex)
		end
	end

	-- Now we move all the non-inserted vertices away from the inserted
	-- vertcies. In an attempt to avoid overlaps.
	-- local insertAABB = Vector.keysAABB(insertions)
	-- local focus = insertAABB:centre()
	-- local scale = 1.25

	-- for graphVertex, _  in pairs(graph.vertices) do
	-- 	if not insertions[graphVertex] then
	-- 		local disp = Vector.to(focus, graphVertex)
	-- 		disp:scale(scale)

	-- 		graphVertex[1] = focus[1] + disp[1]
	-- 		graphVertex[2] = focus[2] + disp[2]
	-- 	end
	-- end

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
	return {
		cosmetic = edge.cosmetic,
		lengthFactor = edge.lengthFactor,
		subdivide = edge.subdivide,
	}
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

function GraphGrammar:build( maxIterations, minVertices, maxVertices, maxValence )
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
			if numVertices + rule.vertexDelta > maxVertices then
				printf('  %s would pop vertex count', name)
			else
				local success, matches = rule:matches(graph, maxValence)

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

			numVertices = numVertices + ruleMatch.rule.vertexDelta
		end

		local finish = love.timer.getMicroTime()
		local duration = finish - start
		totalTime = totalTime + duration

		printf('  %.2fs', duration)

		if numVertices == maxVertices or (stalled and enoughVertices) then
			break
		end
	end

	printf('  total:%.2fs', totalTime)

	return graph
end
