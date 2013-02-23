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
			selection = vertex
		end
	end

	for vertex, _ in pairs(level.rightGraph.vertices) do
		local d = coord:toLength(vertex)
		if d < distance then
			distance = d
			selection = vertex
		end
	end

	if distance > config.tolerance then
		selection = nil
	end

	if state.edge then
		local current = state.selection

		if current and selection then
			local different = current ~= selection
			local sameSide = current.side == selection.side

			if different and sameSide then
				local graph = (current.side == 'left') and level.leftGraph or level.rightGraph

				if not graph:isPeer(current, selection) then
					graph:addEdge({}, current, selection)
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

	love.graphics.setLine(1, 'rough')
	love.graphics.line(hw, 0, hw, h)

	local level = state.stack[state.index]

	local radius = 5

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

	if state.selection then
		local selection = state.selection
		love.graphics.setLine(3, 'rough')
		love.graphics.setColor(255, 255, 255, 255)
		local radius = 10
		love.graphics.circle('line', selection[1], selection[2], radius)

		if state.edge then
			local mx, my = love.mouse.getX(), love.mouse.getY()
			local coord = Vector.new { mx, my }

			love.graphics.line(selection[1], selection[2], coord[1], coord[2])
		end
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
		state.edge = true
	end
end

function graphmode.keyreleased( key )
	if key == 'lshift' or key == 'rshift' then
		state.edge = false
	end
end