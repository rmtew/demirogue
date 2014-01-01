--
-- mode/ForceDrawMode.lua
--
-- Test bed and debugging tool for the force drawing algorithm.
--

require 'Graph'
local AABB = require 'lib/AABB'
require 'Vector'
require 'geometry'
require 'graph2D'
local graphDraw = require 'lib/graphDraw'

local schema, ForceDrawMode = require 'lib/mode' { 'ForceDrawMode' }

local config = {
	tolerance = 20,
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

local graph = Graph.new()
local undo = {}
local log = nil
local logmode = nil
local logmodes = {
	repulse = { 255, 0, 0, 255 },
	attract = { 0, 255, 0, 255 },
	edge = { 0, 0, 255, 255 },
	accum = { 255, 255, 255, 255 },
	proj = { 255, 255, 0, 255 },
	clip = { 255, 0, 255, 255 },
	arc = { 0, 128, 0, 128 },
	plane = { 255, 255, 255, 255 },
}
local selected = nil
local connect = false
local time = 0

function ForceDrawMode:update( dt )
	time = time + dt

	local mx, my = love.mouse.getX(), love.mouse.getY()
	local coord = Vector.new { x = mx, y = my }

	local distance = math.huge
	local selection = nil

	for vertex, _ in pairs(graph.vertices) do
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

		for edge, endverts in pairs(graph.edges) do
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

	if connect then
		assert(selected)
		assert(selected.type == 'vertex')
		local current = selected.vertex

		if selection and selection.type == 'vertex' then
			if current ~= selection.vertex then
				if not graph:isPeer(current, selection.vertex) then
					graph:addEdge({}, current, selection.vertex)
				end
			end
		end
	else
		if selection and distance < config.tolerance then
			selected = selection
		else
			selected = nil
		end
	end
end

local function _render( graph, colour )
	-- Mid-grey.
	love.graphics.setColor(colour[1], colour[2], colour[3], colour[4])
	love.graphics.setLineWidth(3)
	love.graphics.setLineStyle('rough')
	
	for edge, endverts in pairs(graph.edges) do
		local v1, v2 = endverts[1], endverts[2]

		love.graphics.line(v1.x, v1.y, v2.x, v2.y)
	end

	local radius = 5
	for vertex, _ in pairs(graph.vertices) do
		love.graphics.circle('fill', vertex.x, vertex.y, radius)
	end
end

function ForceDrawMode:draw()
	-- Highlight any selection.
	if selected then
		-- yellow
		love.graphics.setColor(255, 255, 0, 255)

		if selected.type == 'vertex' then
			local radius = 10
			local vertex = selected.vertex
			love.graphics.setLineWidth(3)
			love.graphics.setLineStyle('rough')

			if connect then
				-- Magenta!
				love.graphics.setColor(255, 0, 255, 255)

				local mx, my = love.mouse.getX(), love.mouse.getY()
				love.graphics.line(vertex.x, vertex.y, mx, my)
			end

			love.graphics.circle('line', vertex.x, vertex.y, radius)
		end

		if selected.type == 'edge' then
			local endverts = graph.edges[selected.edge]

			love.graphics.setLineWidth(10)
			love.graphics.setLineStyle('rough')
			love.graphics.line(endverts[1].x, endverts[1].y, endverts[2].x, endverts[2].y)
		end
	end

	if #undo > 0 then
		local colour = { 128, 128, 128, 255 }	
		_render(undo[#undo].graph, colour)
	end 

	local colour = { 64, 64, 64, 255 }
	_render(graph, colour)

	if log then
		love.graphics.setLineWidth(1)
		love.graphics.setLineStyle('rough')

		for _, line in ipairs(log) do
			if logmode ~= nil and line[1] == logmode then
				love.graphics.setColor(unpack(logmodes[line[1]]))
				
				if line[1] ~= 'arc' then
					local x1, y1, x2, y2 = line[2], line[3], line[4], line[5]
					love.graphics.line(x1, y1, x2, y2)

					-- draw arrow head

					local dir = Vector.new { x=x1-x2, y=y1-y2 }
					dir:normalise()
					dir:scale(5)
					local arr1 = dir:perp()
					local arr2 = dir:antiPerp()
					
					love.graphics.line(x2, y2, x2+dir.x+arr1.x, y2+dir.y+arr1.y)
					love.graphics.line(x2, y2, x2+dir.x+arr2.x, y2+dir.y+arr2.y)

					love.graphics.line(x1, y1, x1+arr1.x, y1+arr1.y)
					love.graphics.line(x1, y1, x1+arr2.x, y1+arr2.y)
				else
					local x, y = line[2], line[3]
					local dir = line[4]
					local radius = line[5]
					local segments = 10

					local angle = math.atan2(dir.y, dir.x)
					local cw = angle + (math.pi / 8)
					local ccw = angle - (math.pi / 8)

					if radius ~= math.huge then
						love.graphics.arc('fill', x, y, radius, cw, ccw, segments)
						love.graphics.setColor(0, 255, 0, 255)
						love.graphics.arc('line', x, y, radius, cw, ccw, segments)
					end
				end
			end
		end
	end

	_shadowf(gFont15, 0, 0, 'logmode: %s  M.E.L.:%.2f', logmode, graph2D.meanEdgeLength(graph))
end

function ForceDrawMode:mousepressed( x, y, button )
	if button ~= 'l' then
		return
	end

	-- This stops vertices being placed too close to other vertices.
	if selected and selected.type == 'vertex' then
		return
	end

	local coord = Vector.new { x = x, y = y }

	local vertex = {
		x = x, 
		y = y
	}

	graph:addVertex(vertex)
end

function ForceDrawMode:keypressed( key )
	key = key:lower()

	if key == 'delete' or key == 'backspace' then
		if selected then
			if selected.type == 'vertex' then
				graph:removeVertex(selected.vertex)
			else
				graph:removeEdge(selected.edge)
			end
		end

		selected = nil
	elseif key == 'lshift' or key == 'rshift' then
		if selected and selected.type == 'vertex' then
			connect = true
		end
	elseif key == ' ' then
		local stash = {
			graph = graph:clone(table.copy, table.copy),
			log = log
		}
		undo[#undo+1] = stash

		local delta = 100
		local gamma = 50
		local epsilon = 0.1
		local logging = true

		-- log = graphDraw.pred(graph, delta, gamma, epsilon, logging)
		log = graphDraw.demipred(graph, delta, gamma, epsilon, logging)
	elseif key == 'l' then
		logmode = next(logmodes, logmode)
	elseif key == 'u' then
		if #undo > 0 then
			graph = undo[#undo].graph
			log = undo[#undo].log
			undo[#undo] = nil
		end
	end
end

function ForceDrawMode:keyreleased( key )
	if key == 'lshift' or key == 'rshift' then
		connect = false
	end
end
