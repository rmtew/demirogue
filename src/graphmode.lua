require 'Graph'
require 'GraphGrammar'
require 'AABB'
require 'Vector'
require 'geometry'

-- Basic graph editing for making grammar rule sets.
--
-- The screen is split into two panes, left and right.
-- The left pane holds the pattern graph.
-- THe right pane holds the substitute graph.

graphmode = {}

local config = {
	tolerance = 30,
}

local function _shadowf( x, y, ... )
	love.graphics.setColor(0, 0, 0, 255)

	local text = string.format(...)

	love.graphics.print(text, x-1, y-1)
	love.graphics.print(text, x-1, y+1)
	love.graphics.print(text, x+1, y-1)
	love.graphics.print(text, x+1, y+1)

	love.graphics.setColor(192, 192, 192, 255)

	love.graphics.print(text, x, y)
end

local state = nil
local time = 0

function graphmode.update()
	time = time + love.timer.getDelta()

	if not state then
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

		local leftGraph = Graph.new()
		local rightGraph = Graph.new()

		state = {
			leftPane = leftPane,
			rightPane = rightPane,
			stack = {
				{
					leftGraph = leftGraph,
					rightGraph = rightGraph,
					map = {},
				},
			},
			index = 1,
			selection = nil,
			edge = false,
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

function graphmode.draw()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()

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

			table.print(endverts)

			love.graphics.setLine(10, 'rough')
			love.graphics.line(endverts[1][1], endverts[1][2], endverts[2][1], endverts[2][2])
		end
	end

	local radius = 5

	love.graphics.setLine(3, 'rough')
	love.graphics.setColor(255, 0, 0, 255)

	for vertex, _ in pairs(level.leftGraph.vertices) do
		love.graphics.circle('fill', vertex[1], vertex[2], radius)
	end

	for edge, endverts in pairs(level.leftGraph.edges) do
		love.graphics.line(endverts[1][1], endverts[1][2], endverts[2][1], endverts[2][2])
	end

	love.graphics.setColor(0, 255, 0, 255)

	for vertex, _ in pairs(level.rightGraph.vertices) do
		love.graphics.circle('fill', vertex[1], vertex[2], radius)
	end

	for edge, endverts in pairs(level.rightGraph.edges) do
		love.graphics.line(endverts[1][1], endverts[1][2], endverts[2][1], endverts[2][2])
	end

	if state.edge then
		local vertex = state.selection.vertex
		local mx, my = love.mouse.getX(), love.mouse.getY()
		local coord = Vector.new { mx, my }

		love.graphics.line(vertex[1], vertex[2], coord[1], coord[2])
	end
end

function graphmode.mousepressed( x, y, button )
	local coord = { x, y }
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local hw = w * 0.5

	local level = state.stack[state.index]

	if state.leftPane:contains(coord) then
		print('left pane')
		local leftVertex = {
			x,
			y,
			side = 'left',
		}

		local rightVertex = {
			x + hw,
			y,
			side = 'right',
			mapped = true,
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
		}
		level.rightGraph:addVertex(rightVertex)
	end
end

function graphmode.mousereleased( x, y, button )
end

function graphmode.keypressed( key )
	if key == 'lshift' or key == 'rshift' then
		if state.selection and state.selection.type == 'vertex' then
			state.edge = true
		end
	end
end

function graphmode.keyreleased( key )
	if key == 'lshift' or key == 'rshift' then
		state.edge = false
	end
end