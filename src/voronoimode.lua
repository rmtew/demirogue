require 'misc'
require 'Vector'
require 'AABB'
require 'graphgen'
require 'layoutgen'
require 'roomgen'
require 'Level'
require 'texture'
require 'Voronoi'
require 'Viewport'
require 'themes'

local w, h = love.graphics.getWidth(), love.graphics.getHeight()

local bounds = AABB.new {
	xmin = 0,
	ymin = 0,
	xmax = 3 * w,
	ymax = 3 * h,
}

local theme = themes.db.catacomb
local viewport = Viewport.new(bounds)
local minZoom = 1
local maxZoom = 1
local roomColours = nil

local function _gen()
	roomColours = nil

	local level = Level.newThemed(theme)

	local portal = AABB.new {
		xmin = 0,
		xmax = love.graphics.getWidth(),
		ymin = 0,
		ymax = love.graphics.getHeight(),
	}

	minZoom = 0.001
	maxZoom = 1000

	viewport = Viewport.new(level.aabb)

	local wAspect = viewport.bounds:width() / viewport.portal:width()
	local hAspect = viewport.bounds:height() / viewport.portal:height()

	maxZoom = math.max(wAspect, hAspect)
	minZoom = math.min(1/wAspect, 1/hAspect)

	viewport:setZoomImmediate(minZoom)
	
	return level
end

local level
local time = 0

voronoimode = {}

function voronoimode.update()
	local dt = love.timer.getDelta()
	time = time + dt

	if not level then
		level = _gen()
	end

	viewport:update()
end

local drawPoints = false
local drawRoomAABBs = false
local drawNonSkeleton = false
local drawVoronoi = true
local drawHulls = false

local drawEdgesOptions = {
	'none',
	'walkable',
	'all',
}

local drawEdgesIndex = 1
local drawCore = false
local drawFringes = false
local drawRims = false
local drawNonHJKLYUBNCells = false

function shadowf( x, y, ... )
	love.graphics.setColor(0, 0, 0, 255)

	local text = string.format(...)

	love.graphics.print(text, x-1, y-1)
	love.graphics.print(text, x-1, y+1)
	love.graphics.print(text, x+1, y-1)
	love.graphics.print(text, x+1, y+1)

	love.graphics.setColor(192, 192, 192, 255)

	love.graphics.print(text, x, y)
end

function voronoimode.draw()
	love.graphics.push()	
	
	viewport:setup()
	local zoom = viewport:getZoom()
	local scaler = (zoom <  1) and 1/zoom or 1

	love.graphics.setLineStyle('rough')

	if drawVoronoi then
		local linewidth = 2 * scaler

		love.graphics.setLineWidth(linewidth)
		love.graphics.setLineStyle('rough')

		local colours = {
			-- { 0, 0, 0, 255 },
			{ 255, 0, 0, 255 },
			{ 0, 255, 0, 255 },
			{ 0, 0, 255, 255 },
			{ 255, 255, 0, 255 },
			{ 255, 0, 255, 255 },
			{ 0, 255, 255, 255 },
			{ 255, 255, 255, 255 },
		}

		local fringe = {}
		local skeleton = level.skeleton

		fringe = level.graph:multiSourceDistanceMap(skeleton, 2)

		for vertex, _ in pairs(level.graph.vertices) do
			local poly = vertex.poly

			if #poly < 3*2 then
				printf('vertex with only %d components in the poly, need at least 6', #poly)
			else
				local walkable = vertex.terrain.walkable
				local depth = fringe[vertex] or 0

				if fringe[vertex] or drawNonSkeleton then
					local terrain = vertex.terrain
					local colour = terrain.colour
					local r, g, b, a = colour[1], colour[2], colour[3], colour[4] 

					if terrain.shimmer then
						local minf, maxf = 1 - terrain.shimmer, 1 + terrain.shimmer
						local offset = level.distances[vertex] or 0
						local f = lerpf(math.sin(time + offset), -1, 1, minf, maxf)

						r = r * f
						g = g * f
						b = b * f
					end

					love.graphics.setColor(r, g, b, a)
					love.graphics.polygon('fill', poly)
				end
			end
		end

		for vertex, _ in pairs(level.graph.vertices) do
			local poly = vertex.poly

			if #poly < 3*2 then
				printf('vertex with only %d components in the poly, need at least 6', #poly)
			else
				local colour = vertex.terrain.colour
				local walkable = vertex.terrain.walkable

				if walkable or drawRims then
					love.graphics.setColor(0, 0, 0, 255)
					love.graphics.polygon('line', poly)
				end
			end
		end
	end

	if drawFringes then
		if not roomColours then
			local colours = {
				{ 255, 0, 0, 255 },
				{ 0, 255, 0, 255 },
				{ 0, 0, 255, 255 },
				{ 255, 255, 0, 255 },
				{ 255, 0, 255, 255 },
				{ 0, 255, 255, 255 },
			}

			roomColours = {}

			for room, fringe in pairs(level.fringes) do
				local colour = colours[math.random(1, #colours)]
				roomColours[room] = colour
			end
		end

		local maxdepth = math.round(time*10) % (level.maxFringeDepth + 1)

		for room, fringe in pairs(level.fringes) do
			local colour = roomColours[room]
			love.graphics.setColor(unpack(colour))
			for vertex, depth in pairs(fringe) do
				if depth == maxdepth then
					love.graphics.polygon('line', vertex.poly)
				end
			end
		end
	end

	if drawRoomAABBs then
		love.graphics.setLineWidth(3 * scaler)
		love.graphics.setColor(0, 255, 0, 255)

		for index, room in ipairs(level.rooms) do
			local aabb = room.aabb
			love.graphics.rectangle('line', aabb.xmin, aabb.ymin, aabb:width(), aabb:height())
		end
	end

	if drawHulls then
		love.graphics.setColor(255, 255, 0, 255)
		
		for _, room in ipairs(level.rooms) do
			local vertices = {}

			for _, point in ipairs(room.hull) do
				vertices[#vertices+1] = point.x
				vertices[#vertices+1] = point.y
			end

			love.graphics.polygon('line', vertices)
		end
	end

	if drawEdgesIndex ~= 1 then
		love.graphics.setColor(0, 0, 255, 255)
		local linewidth = 3 * scaler
		love.graphics.setLineWidth(linewidth * viewport:getZoom())
		love.graphics.setLineStyle('rough')

		local drawUnwalkableEdges = drawEdgesOptions[drawEdgesIndex] == 'all'
		
		for edge, endverts in pairs(level.graph.edges) do
			local walkable = endverts[1].terrain.walkable and endverts[2].terrain.walkable

			if drawUnwalkableEdges or walkable then
				love.graphics.line(endverts[1].x, endverts[1].y, endverts[2].x, endverts[2].y)
			end
		end

		local radius = 4 * scaler

		for vertex, _ in pairs(level.graph.vertices) do
			if drawUnwalkableEdges or vertex.terrain.walkable then
				love.graphics.circle('fill', vertex.x, vertex.y, radius)
			end
		end
	end

	if drawPoints then
		love.graphics.setColor(255, 0 , 255, 255)

		for index, room in ipairs(level.rooms) do
			for _, point in ipairs(room.points) do
				local radius = 2
				love.graphics.circle('fill', point.x, point.y, radius)
			end
		end

		love.graphics.setColor(255, 255 , 255, 255)

		for index, point in ipairs(level.corridors) do
			local radius = 3
			love.graphics.circle('fill', point.x, point.y, radius)
		end

		if drawNonSkeleton then
			love.graphics.setColor(128, 128 , 128, 255)

			for index, point in ipairs(level.walls) do
				local radius = 3
				love.graphics.circle('fill', point.x, point.y, radius)
			end
		end

		for vertex, _ in pairs(level.graph.vertices) do
			local localeId = vertex.localeId
			local distance = level.distances[vertex]

			local text = nil

			if localeId then
				text = string.format("%d", localeId)
			end

			if distance then
				text = (text or '') .. tostring(distance)
			end

			if text then
				shadowf(vertex.x, vertex.y, text)
			end
		end
	end

	if drawCore then
		love.graphics.setColor(0, 0, 255, 128)
		love.graphics.setLineWidth(1)
		for _, core in ipairs(level.cores) do
			love.graphics.polygon('fill', core)
		end
	end

	-- Cells with more than 8 neightbours would problematic for traditional
	-- roguelike movement controls, hjklyubn or numpad.
	if drawNonHJKLYUBNCells then
		for vertex, peers in pairs(level.graph.vertices) do
			if table.count(peers) > 8 then
				love.graphics.setColor(0, 0, 0, 128)
				local radius = 10
				love.graphics.circle('fill', vertex.x, vertex.y, radius)
			end
		end
	end

	-- love.graphics.setLineWidth(5)
	-- love.graphics.setColor(0, 0, 0, 128)
	-- local centre = viewport.centreDamp.value
	-- love.graphics.circle('line', centre[1], centre[2], 10)
	-- love.graphics.setColor(255, 0, 0, 128)
	-- local centre = viewport.portal:centre()
	-- love.graphics.circle('line', centre[1], centre[2], 10)

	love.graphics.pop()

	local numPoints = 0

	for index, room in ipairs(level.rooms) do
		numPoints = numPoints + #room.points
	end

	shadowf(10, 10, 'fps:%.2f <%s> %d/%d',
		love.timer.getFPS(),
		theme.name,
		numPoints,
		table.count(level.graph.vertices))
end

function voronoimode.mousepressed( x, y, button )
	local screen = Vector.new { x = x, y = y }
	local world = viewport:screenToWorld(screen)

	viewport:setCentre(world)

	if button == 'wu' then
		local zoom = viewport:getZoom()

		if zoom < maxZoom then
			viewport:setZoom(math.min(maxZoom, zoom * 1.5))
			printf('zoom:%.2f -> %.2f', zoom, viewport:getZoom())
		end
	elseif button == 'wd' then
		local zoom = viewport:getZoom()

		if zoom > minZoom then
			viewport:setZoom(math.max(minZoom, zoom * 0.75))
			printf('zoom:%.2f -> %.2f', zoom, viewport:getZoom())
		end
	end
end

function voronoimode.mousereleased( x, y, button )
end

-- TODO: need a proper declarative interface for setting up controls.
function voronoimode.keypressed( key )
	if key == 'a' then
		drawRoomAABBs = not drawRoomAABBs
	elseif key == 's' then
		drawNonSkeleton = not drawNonSkeleton
	elseif key == 'v' then
		drawVoronoi = not drawVoronoi
	elseif key == 'h' then
		drawHulls = not drawHulls
	elseif key == 'e' then
		drawEdgesIndex = drawEdgesIndex + 1

		if drawEdgesIndex > #drawEdgesOptions then
			drawEdgesIndex = 1
		end
	elseif key == 'p' then
		drawPoints = not drawPoints
	-- elseif key == 'f' or key == 'F' then
	-- 	drawFringes = not drawFringes

	-- 	if drawFringes and love.keyboard.isDown('lshift', 'rshift') then
	-- 		for room, fringe in pairs(level.fringes) do
	-- 			local r = math.random()

	-- 			if r < 1/3 then
	-- 				for vertex, depth in pairs(fringe) do
	-- 					vertex.terrain = terrains.tree
	-- 				end
	-- 			elseif r < 2/3 then
	-- 				for vertex, depth in pairs(fringe) do
	-- 					vertex.terrain = terrains.water
	-- 				end
	-- 			else
	-- 				for vertex, depth in pairs(fringe) do
	-- 					vertex.terrain = terrains.lava
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	elseif key == 'r' then
		drawRims = not drawRims
	elseif key == ' ' then
		level = _gen()
	elseif key == 'left' then
		theme = themes.db[theme.prevTheme]
		level = _gen()
	elseif key == 'right' then
		theme = themes.db[theme.nextTheme]
		level = _gen()
	end
end

function voronoimode.keyreleased( key )
end
