require 'Graph'
require 'GraphGrammar'
require 'AABB'
require 'Vector'
require 'geometry'
require 'graph2D'

require 'themes'

-- Basic graph editing for making grammar rule sets.
--
-- The screen is split into two panes, left and right.
-- The left pane holds the pattern graph.
-- THe right pane holds the substitute graph.

graphmode = {}

local config = {
	tolerance = 30,
}

local function _shadowf(font, x, y, ... )
	love.graphics.setFont(font)
	love.graphics.setColor(0, 0, 0, 255)

	local text = string.format(...)

	love.graphics.print(text, x-1, y-1)
	love.graphics.print(text, x-1, y+1)
	love.graphics.print(text, x+1, y-1)
	love.graphics.print(text, x+1, y+1)

	love.graphics.setColor(192, 192, 192, 255)

	love.graphics.print(text, x, y)
end

local function _save( state )
	-- Make a nice to save version of the state.

	-- { level }+
	-- level = { leftGraph = graph, rightGraph = graph, map = map }
	-- graph = { vertices = { vertex }+, edges = { edge }+ }
	-- edge = { <index>, <index>, cosmetic = <boolean>, subdivide = <boolean> }
	-- vertex = { <x>, <y>, side = 'left'|'right', tag = <string>, mapped = <boolean>|nil }
	-- map = { [<index>] = <index> }*

	local function _vertex( vertex )
		if vertex.side == 'left' then
			return {
				vertex[1],
				vertex[2],
				side = 'left',
				tags = table.copy(vertex.tags),
				lock = vertex.lock and true or false,
			}
		else
			return { 
				vertex[1],
				vertex[2],
				side = 'right',
				tag = vertex.tag,
				mapped = vertex.mapped and true or false,
			}
		end
	end

	local function _graph( graph )
		local vertexIndices = {}
		local nextVertexIndex = 1
		local vertices = {}

		for vertex, _ in pairs(graph.vertices) do
			local copy = _vertex(vertex)
			vertices[nextVertexIndex] = copy
			vertexIndices[vertex] = nextVertexIndex
			nextVertexIndex = nextVertexIndex + 1
		end

		local edges = {}

		for edge, endverts in pairs(graph.edges) do
			local vertex1Index = vertexIndices[endverts[1]]
			local vertex2Index = vertexIndices[endverts[2]]
			local cosmetic = edge.cosmetic and true or false
			local subdivide = edge.subdivide and true or false

			edges[#edges+1] = {
				vertex1Index,
				vertex2Index,
				cosmetic = cosmetic,
				subdivide = subdivide,
			}
		end

		return { vertices = vertices, edges = edges }, vertexIndices
	end

	local function _level( level )
		local leftGraph, leftVertexIndices = _graph(level.leftGraph)
		local rightGraph, rightVertexIndices = _graph(level.rightGraph)

		local map = {}

		for leftVertex, rightVertex in pairs(level.map) do
			map[leftVertexIndices[leftVertex]] = rightVertexIndices[rightVertex]
		end

		return {
			leftGraph = leftGraph,
			rightGraph = rightGraph,
			map = map
		}
	end

	local levels = {}

	for index, level in ipairs(state.stack) do
		local copy = _level(level)
		levels[index] = copy
	end

	return levels
end

local function _load( data )
	-- Turn the saved version of the state into a runtime usable version.

	-- { level }+
	-- level = { leftGraph = graph, rightGraph = graph, map = map }
	-- graph = { vertices = { vertex }+, edges = { { <index>, <index> } }+ }
	-- vertex = { <x>, <y>, side = 'left'|'right', tag = <string>, mapped = <boolean>|nil }
	-- map = { [<index>] = <index> }*

	local function _vertex( vertex )
		if vertex.side == 'left' then
			return {
				vertex[1],
				vertex[2],
				side = 'left',
				tags = table.copy(vertex.tags),
				lock = vertex.lock and true or false,
			}
		else
			return { 
				vertex[1],
				vertex[2],
				side = 'right',
				tag = vertex.tag,
				mapped = vertex.mapped and true or false,
			}
		end
	end

	local function _graph( graph )
		local vertexIndices = {}

		local result = Graph.new()

		for index, vertex in ipairs(graph.vertices) do
			local copy = _vertex(vertex)
			result:addVertex(copy)
			vertexIndices[index] = copy
		end

		for _, edge in pairs(graph.edges) do
			local side = vertexIndices[edge[1]].side
			local cosmetic = edge.cosmetic and true or false
			local subdivide = edge.subdivide and true or false
			local newEdge = {
				side = side,
				cosmetic = cosmetic,
				subdivide = subdivide,
			} 
			result:addEdge(newEdge, vertexIndices[edge[1]], vertexIndices[edge[2]])
		end

		return result, vertexIndices
	end

	local function _level( level )
		local leftGraph, leftVertexIndices = _graph(level.leftGraph)
		local rightGraph, rightVertexIndices = _graph(level.rightGraph)

		local map = {}

		for leftVertexIndex, rightVertexIndex in pairs(level.map) do
			map[leftVertexIndices[leftVertexIndex]] = rightVertexIndices[rightVertexIndex]
		end

		return {
			leftGraph = leftGraph,
			rightGraph = rightGraph,
			map = map
		}
	end

	local result = {}

	for index, level in ipairs(data) do
		local copy = _level(level)

		result[index] = copy
	end

	return result	
end

-- This getting complicated enough to possibly require an object.
--
-- state = {
--     leftPane = <AABB>,
--     rightPane = <AABB>,
--     index = [1..#stack],
--     stack = {
--        {
--            leftGraph = <Graph>,
--            rightGraph = <Graph>,
--            map = { [<leftGraphVertex>] = <rightGraphVertex> },
--        }
--     }+,
--     selection = nil
--         | { type = 'vertex', vertex = <leftGraphVertex>|<rightGraphVertex> }
--         | { type = 'edge', vertex = <leftGraphEdge>|<rightGraphEdge> },
--     edge = <boolean>,
--     show = <boolean>,
--     graph = nil | <Graph>,
--     coro = <coroutine>,
--     themeIndex = [1..#theme.sortedDB]
-- }

local function _calculateLengthFactors( level )
	local leftGraph = level.leftGraph
	local rightGraph = level.rightGraph

	local meanLeftEdgeLength = graph2D.meanEdgeLength(leftGraph)
	local meanRightEdgeLength = graph2D.meanEdgeLength(rightGraph)

	-- print('length factors', meanLeftEdgeLength, meanRightEdgeLength)

	local meanEdgeLength = meanLeftEdgeLength

	if meanEdgeLength == 0 then
		meanEdgeLength = meanRightEdgeLength
	end

	if meanEdgeLength > 0 then
		for rightEdge, rightEndVerts in pairs(rightGraph.edges) do
			if rightEdge.subdivide then
				local edgeLength = Vector.toLength(rightEndVerts[1], rightEndVerts[2])

				local lengthFactor = edgeLength / meanEdgeLength

				-- print(edgeLength, meanEdgeLength, lengthFactor)

				rightEdge.lengthFactor = lengthFactor
			end
		end
	end
end

local function _rule( level )
	_calculateLengthFactors(level)

	local pattern = level.leftGraph
	local substitute = level.rightGraph
	local map = level.map
	local status, result = pcall(
		function ()
			return GraphGrammar.Rule.new(pattern, substitute, map)
		end)
	
	if status then
		return result
	else
		return nil, result
	end
end

local function _rules( stack )
	local rules = {}
	local nextRuleId = 1

	for _, level in ipairs(stack) do
		local rule = _rule(level)

		if rule then
			local name = string.format("rule%d", nextRuleId)
			printf('RULE %s!', name)
			nextRuleId = nextRuleId + 1
			rules[name] = rule
		else
			print('RULE FAIL')
		end
	end

	print('RULEZ', #stack, table.count(rules))

	return rules
end


local state = nil
local time = 0

function graphmode.update()
	time = time + love.timer.getDelta()

	if not state then
		table.print(themes.db)
		local w, h = love.graphics.getWidth(), love.graphics.getHeight()
		local hw = w * 0.5

		local leftPane = AABB.new {
			xmin = 0,
			xmax = hw,
			ymin = 0,
			ymax = h,
		}

		local rightPane = AABB.new {
			xmin = hw,
			xmax = w,
			ymin = 0,
			ymax = h,
		}

		local themeIndex = 1
		local theme = themes.sortedDB[themeIndex]
		local stack = _load(theme.ruleset())

		local leftGraph = Graph.new()
		local rightGraph = Graph.new()

		state = {
			leftPane = leftPane,
			rightPane = rightPane,
			stack = stack,
			index = 1,
			selection = nil,
			edge = false,
			show = false,
			graph = nil,
			coro = nil,
			themeIndex = themeIndex,
			theme = theme,
		}
	end

	local level = state.stack[state.index]
	local mx, my = love.mouse.getX(), love.mouse.getY()
	local coord = Vector.new { mx, my }

	local distance = math.huge
	local selection = nil

	for vertex, _ in pairs(level.leftGraph.vertices) do
		local d = coord:toLength(vertex)
		if d < distance then
			distance = d
			selection = { type = 'vertex', vertex = vertex }
		end
	end

	for vertex, _ in pairs(level.rightGraph.vertices) do
		local d = coord:toLength(vertex)
		if d < distance then
			distance = d
			selection = { type = 'vertex', vertex = vertex }
		end
	end

	if distance > config.tolerance then
		selection = nil
	end

	-- What about an edge?
	if not selection then
		distance = math.huge

		for edge, endverts in pairs(level.leftGraph.edges) do
			local d = geometry.closestPointOnLine(endverts[1], endverts[2], coord):toLength(coord)

			if d < distance then
				distance = d
				selection = { type = 'edge', edge = edge }
			end
		end

		for edge, endverts in pairs(level.rightGraph.edges) do
			local d = geometry.closestPointOnLine(endverts[1], endverts[2], coord):toLength(coord)

			if d < distance then
				distance = d
				selection = { type = 'edge', edge = edge }
			end
		end
		
		if distance > config.tolerance then
			selection = nil
		end
	end

	if state.edge then
		assert(state.selection and state.selection.type == 'vertex')

		local current = state.selection.vertex

		if selection and selection.type == 'vertex' then
			local different = current ~= selection.vertex
			local sameSide = current.side == selection.vertex.side

			if different and sameSide then
				local graph = (current.side == 'left') and level.leftGraph or level.rightGraph

				if not graph:isPeer(current, selection.vertex) then
					graph:addEdge({ side = current.side }, current, selection.vertex)
				end
			end
		end
	else
		if selection and distance < config.tolerance then
			state.selection = selection
		else
			state.selection = nil
		end
	end
end

local autoProgress = false
local showLengthFactors = false

local function _tags( vertex )
	assert(vertex.side == 'left')

	local parts = {}

	for tag, _ in pairs(vertex.tags) do
		parts[#parts+1] = tag
	end

	table.sort(parts)

	return table.concat(parts, ',')
end

function graphmode.draw()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local screen = AABB.new {
		xmin = 0,
		xmax = w,
		ymin = 0,
		ymax = h,
	}

	if not state.show then
		local hw = w * 0.5

		-- Dividing line.
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setLine(1, 'rough')
		love.graphics.line(hw, 0, hw, h)

		local level = state.stack[state.index]

		-- Highlight any selection.
		if state.selection then
			local selection = state.selection

			love.graphics.setColor(255, 255, 0, 255)

			if selection.type == 'vertex' then
				love.graphics.setLine(3, 'rough')
				local radius = 10
				love.graphics.circle('line', selection.vertex[1], selection.vertex[2], radius)
			end

			if selection.type == 'edge' then
				local graph = (selection.edge.side == 'left') and level.leftGraph or level.rightGraph
				local endverts = graph.edges[selection.edge]

				love.graphics.setLine(10, 'rough')
				love.graphics.line(endverts[1][1], endverts[1][2], endverts[2][1], endverts[2][2])
			end
		end

		-- Now the vertices and edges.
		local radius = 5

		love.graphics.setLine(3, 'rough')
		love.graphics.setColor(255, 0, 0, 255)

		for vertex, _ in pairs(level.leftGraph.vertices) do
			love.graphics.circle('fill', vertex[1], vertex[2], radius)

			if vertex.lock then
				local extent = 15
				local halfExtent = extent * 0.5
				love.graphics.rectangle('line', vertex[1] - halfExtent, vertex[2] - halfExtent, extent, extent)
			end
		end

		for edge, endverts in pairs(level.leftGraph.edges) do
			if edge.cosmetic then
				love.graphics.setColor(128, 128, 128, 128)
			else
				love.graphics.setColor(255, 0, 0, 255)
			end
			love.graphics.line(endverts[1][1], endverts[1][2], endverts[2][1], endverts[2][2])
		end

		love.graphics.setColor(0, 0, 255, 255)

		for vertex, _ in pairs(level.rightGraph.vertices) do
			love.graphics.circle('fill', vertex[1], vertex[2], radius)

			if vertex.lock then
				local extent = 10
				local halfExtent = extent * 0.5
				love.graphics.rectangle('line', vertex[1] - halfExtent, vertex[2] - halfExtent, extent, extent)
			end
		end

		for edge, endverts in pairs(level.rightGraph.edges) do
			if edge.cosmetic and not edge.subdivide then
				love.graphics.setColor(128, 128, 128, 128)
			elseif edge.subdivide then
				if edge.cosmetic then
					love.graphics.setColor(255, 128, 255, 128)
				else
					love.graphics.setColor(255, 0, 255, 255)
				end
			else
				love.graphics.setColor(0, 0, 255, 255)
			end
			love.graphics.line(endverts[1][1], endverts[1][2], endverts[2][1], endverts[2][2])
		end

		love.graphics.setColor(255, 255, 255, 255)

		-- Now draw the tags.
		for vertex, _ in pairs(level.leftGraph.vertices) do
			_shadowf(gFont30, vertex[1], vertex[2], '%s', _tags(vertex))
		end

		for vertex, _ in pairs(level.rightGraph.vertices) do
			_shadowf(gFont30, vertex[1], vertex[2], '%s', vertex.tag)
		end

		-- If we're in edge mode draw a line to help.
		if state.edge then
			local vertex = state.selection.vertex
			local mx, my = love.mouse.getX(), love.mouse.getY()
			local coord = Vector.new { mx, my }

			love.graphics.line(vertex[1], vertex[2], coord[1], coord[2])
		end

		-- TODO: got to try and build a GraphGrammar Rule and tell the user if
		--       it fails or succeeds.
		local rule, msg = _rule(state.stack[state.index])

		-- Remove the file and line part of the assert msg.
		if msg then
			msg = 'invalid: ' .. msg:match('^.+:(.*)$')
		end

		_shadowf(gFont15, 10, 10, '%s #%d/%d %s', state.theme.name, state.index, #state.stack, msg or 'ok')
	else
		if state.coro then
			if autoProgress then
				gProgress = true
			end

			local status, result = coroutine.resume(state.coro)

			if not status then
				error(result)
			end

			if result == nil then
				state.coro = nil
			else
				state.graph = result
			end
		end

		local aabb = AABB.new { xmin = 0, xmax = 0, ymin = 0, ymax = 0 }
		if not state.graph:isEmpty() then
			aabb = graph2D.aabb(state.graph)
		end

		local width = math.ceil(aabb:width())
		local height = math.ceil(aabb:height())

		-- In case of zero area AABB.
		aabb = aabb:shrink(-1)

		-- If there are any vertices with circles, exapnd the AABB to fit them.
		local maxRadius = 0

		for vertex, _ in pairs(state.graph.vertices) do
			maxRadius = math.max(maxRadius, vertex.radius or 0)
		end

		aabb = aabb:shrink(-maxRadius)

		-- Grow the AABB to be in the same proportions as the screen so when we
		-- lerp vertex positions it doesn't scale the graph.
		aabb:similarise(screen)

		love.graphics.setColor(0, 255, 0, 255)
		love.graphics.setLine(3, 'rough')
		local radius = 5

		for vertex, _ in pairs(state.graph.vertices) do
			local pos = aabb:lerpTo(vertex, screen)

			if vertex.radius then
				local scale = screen:width() / aabb:width()
				local scaledRadius = scale * vertex.radius
				-- love.graphics.circle('line', pos[1], pos[2], scaledRadius)

				local extent = math.sqrt((scaledRadius^2) * 0.5)
				love.graphics.rectangle('line', pos[1] - extent, pos[2] - extent, 2 * extent, 2 * extent)
			else
				love.graphics.circle('fill', pos[1], pos[2], radius)
			end

			local points = vertex.points
			if points then
				local offset = Vector.new { 0, 0 }
				for _, point in pairs(points) do
					offset[1] = vertex[1] + point[1]
					offset[2] = vertex[2] + point[2]

					local pos = aabb:lerpTo(offset, screen)
					love.graphics.point(pos[1], pos[2])
				end
			end
		end

		local theme = state.theme

		for edge, endverts in pairs(state.graph.edges) do
			local length = Vector.toLength(endverts[1], endverts[2])
			
			local pos1 = aabb:lerpTo(endverts[1], screen)
			local pos2 = aabb:lerpTo(endverts[2], screen)

			local lengthFactor = edge.lengthFactor or 1
			local desiredLength = (edge.length or theme.edgeLength) * lengthFactor

			if edge.cosmetic then
				love.graphics.setColor(128, 128, 128, 128)
			elseif length > desiredLength then
				love.graphics.setColor(0, 255, 0, 255)
			else
				love.graphics.setColor(0, 0, 255, 255)
			end

			love.graphics.line(pos1[1], pos1[2], pos2[1], pos2[2])

			if showLengthFactors then
				local mid = Vector.to(pos1, pos2)
				mid:scale(0.5)
				mid[1] = mid[1] + pos1[1]
				mid[2] = mid[2] + pos1[2]
				local scale = length / desiredLength
				_shadowf(gFont15, mid[1], mid[2], '%.3f x%.2f', lengthFactor, scale)
			end
		end

		love.graphics.setColor(0, 255, 0, 255)

		for vertex, _ in pairs(state.graph.vertices) do
			local pos = aabb:lerpTo(vertex, screen)
			_shadowf(gFont30, pos[1], pos[2], '%s', vertex.tag)
		end

		_shadowf(gFont15, 0, 0, 'w:%d h:%d', width, height)

		local failed, msg = graph2D.isSelfIntersecting(state.graph)

		_shadowf(gFont15, 0, 15, 'ok: %s - %s', tostring(not failed), msg or '')
	end
end

function graphmode.mousepressed( x, y, button )
	if button ~= 'l' then
		return
	end

	-- This stops vertices being placed too close to other vertices.
	if state.selection and state.selection.vertex then
		return
	end

	local coord = { x, y }
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local hw = w * 0.5

	local level = state.stack[state.index]

	-- If we're adding a vertex to the left graph we need to add a
	-- corresponding to the right graph.
	if state.leftPane:contains(coord) then
		print('left pane')
		local leftVertex = {
			x,
			y,
			side = 'left',
			tags = { a = true },
			lock = false,
		}

		local rightVertex = {
			x + hw,
			y,
			side = 'right',
			mapped = true,
			tag = 'a',
			lock = false,
			subdivide = false,
		}

		level.leftGraph:addVertex(leftVertex)
		level.rightGraph:addVertex(rightVertex)

		level.map[leftVertex] = rightVertex
	elseif state.rightPane:contains(coord) then
		print('right pane')
		local rightVertex = {
			x,
			y,
			side = 'right',
			mapped = false,
			tag = 'a',
			lock = false,
			subdivide = false,
		}
		level.rightGraph:addVertex(rightVertex)
	end
end

function graphmode.mousereleased( x, y, button )
end

function graphmode.keypressed( key )
	key = key:lower()

	if key == 'lshift' or key == 'rshift' then
		if state.selection and state.selection.type == 'vertex' then
			state.edge = true
		end
	elseif key == 'delete' then
		state.stack[state.index] = {
			leftGraph = Graph.new(),
			rightGraph = Graph.new(),
			map = {},
		}
	elseif key == 'backspace' then
		if state.selection then
			local selection = state.selection
			local level = state.stack[state.index]

			if selection.type == 'vertex' then
				local vertex = selection.vertex
				
				if vertex.side == 'left' then
					level.leftGraph:removeVertex(vertex)
					level.rightGraph:removeVertex(level.map[vertex])
					level.map[vertex] = nil
				elseif not vertex.mapped then
					level.rightGraph:removeVertex(vertex)
				end
			else
				local edge = selection.edge
				local graph = (edge.side == 'left') and level.leftGraph or level.rightGraph

				graph:removeEdge(edge)
			end
		end
	elseif key:find('^([a-z])$') then
		print('tag', key)
		if state.selection and state.selection.type == 'vertex' then
			local vertex = state.selection.vertex

			if vertex.side == 'right' then
				vertex.tag = key
			else
				local append = love.keyboard.isDown('lshift', 'rshift')

				-- It makes no sense to have start vertices be in a tag set.
				if append and key ~= 's' then
					vertex.tags[key] = true
				else
					vertex.tags = { [key] = true }
					-- No point setting the right hand vertex to 's'.
					if tag ~= 's' then
						local level = state.stack[state.index]
						level.map[vertex].tag = key
					end
				end

				table.print(vertex.tags)
			end
		end
	elseif key == 'up' then
		if state.index > 1 then
			state.index = state.index - 1
		end
	elseif key == 'down' then
		local level = state.stack[state.index]

		-- No point having loads of empty rules.
		if not level.leftGraph:isEmpty() and not level.rightGraph:isEmpty() then
			state.index = state.index + 1

			if not state.stack[state.index] then
				state.stack[state.index] = {
					leftGraph = Graph.new(),
					rightGraph = Graph.new(),
					map = {},
				}
			end
		end
	elseif key == 'left' then
		local nextThemeIndex = state.themeIndex - 1
		if nextThemeIndex < 1 then
			nextThemeIndex = #themes.sortedDB
		end

		local nextTheme = themes.sortedDB[nextThemeIndex]
		assert(nextTheme)

		local nextStack = _load(nextTheme.ruleset())

		state.themeIndex = nextThemeIndex
		state.theme = nextTheme
		state.stack = nextStack
		state.index = 1
	elseif key == 'right' then
		local nextThemeIndex = state.themeIndex + 1
		if nextThemeIndex > #themes.sortedDB then
			nextThemeIndex = 1
		end

		local nextTheme = themes.sortedDB[nextThemeIndex]
		assert(nextTheme)

		local nextStack = _load(nextTheme.ruleset())

		state.themeIndex = nextThemeIndex
		state.theme = nextTheme
		state.stack = nextStack
		state.index = 1
	elseif key == 'f5' then
		themes.saveRuleset(state.theme, _save(state))
	elseif key == 'f8' then
		state.stack = _load(state.theme.ruleset())
	elseif key == ' ' then
		autoProgress = false
		local shift = love.keyboard.isDown('lshift', 'rshift')
		local ctrl = love.keyboard.isDown('lctrl', 'rctrl')

		-- If you're not holding shift we do a nice animated level construction
		-- that shows the process. If you hold shift we do it as fast as
		-- possible and display the final result.

		local theme = state.theme

		local springStrength = theme.springStrength
		local edgeLength = theme.edgeLength
		local repulsion = theme.repulsion
		local maxDelta = theme.maxDelta
		local convergenceDistance = theme.convergenceDistance

		-- local springStrength = 1
		-- local edgeLength = 1
		-- local repulsion = 1
		-- local maxDelta = 0.01
		-- local convergenceDistance = 0.05

		local relaxSpringStrength = theme.relaxSpringStrength
		local relaxEdgeLength = theme.relaxEdgeLength
		local relaxRepulsion = theme.relaxRepulsion
		local relaxMaxDelta = theme.relaxMaxDelta
		local relaxConvergenceDistance = theme.relaxConvergenceDistance
		
		local maxIterations = theme.maxIterations
		local minVertices = theme.minVertices
		local maxVertices = theme.maxVertices
		local maxValence = theme.maxValence

		if not shift and not ctrl then
			state.show = not state.show
			state.graph = nil

			if state.show then
				local rules = _rules(state.stack)

				local grammar = GraphGrammar.new {
					rules = rules,

					springStrength = springStrength,
					edgeLength = edgeLength,
					repulsion = repulsion,
					maxDelta = maxDelta,
					convergenceDistance = convergenceDistance,
					drawYield = true,
					replaceYield = true,
				}

				state.coro = coroutine.create(
					function ()
						local graph = grammar:build(maxIterations, minVertices, maxVertices, maxValence)

						local yield = true
						graph2D.assignVertexRadiusAndRelax(
							graph,
							theme.minRadius,
							theme.maxRadius,
							theme.radiusFudge,
							relaxSpringStrength,
							relaxEdgeLength,
							relaxRepulsion,
							relaxMaxDelta,
							relaxConvergenceDistance,
							yield )
					end)
			end
		elseif shift then
			local rules = _rules(state.stack)

			local grammar = GraphGrammar.new {
				rules = rules,

				springStrength = springStrength,
				edgeLength = edgeLength,
				repulsion = repulsion,
				maxDelta = maxDelta,
				convergenceDistance = convergenceDistance,
				drawYield = false,
				replaceYield = false,
			}

			state.graph = grammar:build(maxIterations, minVertices, maxVertices, maxValence)

			local yield = false
			graph2D.assignVertexRadiusAndRelax(
				state.graph,
				theme.minRadius,
				theme.maxRadius,
				theme.radiusFudge,
				relaxSpringStrength,
				relaxEdgeLength,
				relaxRepulsion,
				relaxMaxDelta,
				relaxConvergenceDistance,
				yield)

			state.show = true
			state.coro = nil
		elseif ctrl then
			local rules = _rules(state.stack)

			local grammar = GraphGrammar.new {
				rules = rules,

				springStrength = springStrength,
				edgeLength = edgeLength,
				repulsion = repulsion,
				maxDelta = maxDelta,
				convergenceDistance = convergenceDistance,
				drawYield = false,
				replaceYield = false,
			}

			state.coro = coroutine.create(
				function ()
					local totalDuration = 0
					local numFailures = 0
					local numSucceesses = 0
					while true do
						local start = love.timer.getMicroTime()
						local graph = grammar:build(maxIterations, minVertices, maxVertices, maxValence)

						local yield = false
						graph2D.assignVertexRadiusAndRelax(
							graph,
							theme.minRadius,
							theme.maxRadius,
							theme.radiusFudge,
							relaxSpringStrength,
							relaxEdgeLength,
							relaxRepulsion,
							relaxMaxDelta,
							relaxConvergenceDistance,
							yield)

						local failed, msg = graph2D.isSelfIntersecting(graph)
						local finish = love.timer.getMicroTime()

						if failed then
							numFailures = numFailures + 1
						else
							numSucceesses = numSucceesses + 1
						end

						local total = numFailures + numSucceesses
						local percentage = math.round((numSucceesses / total) * 100)

						local duration = finish - start
						local totalDuration = totalDuration + duration
						_shadowf(gFont30, 0, 40, 'SUCCESS: %d%% (%d/%d) %.2f/s', percentage, numSucceesses, total, total / totalDuration)

						if not failed then
							while not gProgress do
								if autoProgress then
									gProgress = true
								end
								coroutine.yield(graph)
							end
							gProgress = false
						end
					end
				end)

			state.show = true
		end
	elseif key == '=' then
		local selection = state.selection
		if selection and selection.type == 'vertex' and selection.vertex.side == 'left' then
			print('locked!')
			selection.vertex.lock = not selection.vertex.lock
		end
	elseif key == 'return' then
		gProgress = true
	elseif key == 'tab' then
		if state.show then
			autoProgress = not autoProgress
		end
	elseif key == '~' then
		local selection = state.selection
		if selection and selection.type == 'edge' then
			local edge = selection.edge
			edge.cosmetic = not edge.cosmetic
		end
	elseif key == '$' then
		local selection = state.selection
		if selection and selection.type == 'edge' and selection.edge.side == 'right' then
			local edge = selection.edge
			edge.subdivide = not edge.subdivide
			print('subdivide')
		end
	elseif key == '-' then
		local selection = state.selection
		if selection and selection.type == 'vertex' then
			local vertex = selection.vertex

			if vertex.side == 'right' and vertex.mapped then
				vertex.tag = '-'
			elseif vertex.side == 'left' then
				vertex.tags = { ['-'] = true }
			end
		end
	elseif key == '#' then
		showLengthFactors = not showLengthFactors
	end
end

function graphmode.keyreleased( key )
	if key == 'lshift' or key == 'rshift' then
		state.edge = false
	end
end
