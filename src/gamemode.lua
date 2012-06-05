require 'misc'
require 'Vector'
require 'AABB'
require 'graphgen'
require 'layoutgen'
require 'roomgen'
require 'Level'
require 'Actor'
require 'Scheduler'
require 'action'
require 'KDtree'
require 'metalines'
require 'texture'

local w, h = love.graphics.getWidth(), love.graphics.getHeight()
local camx, camy = 0, 0
local track = false
local actions = {}
local playerAction = nil


local function _gen()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()

	local rgen =
		function ( ... )
			local r = math.random()
			if r < 0.33 then
				-- return roomgen.browniangrid(...)
				return roomgen.cellulargrid(...)
			elseif r < 0.66 then
				return roomgen.random(...)
			else
				return roomgen.hexgrid(...)
			end
		end

	local level = Level.new {
		aabb = AABB.new {
			xmin = -w,
			ymin = -h,
			xmax = 2 * w,
			ymax = 2 * h,
		},
		margin = 50,
		-- margin = 100,
		layout = layoutgen.splat,
		roomgen = rgen,
		graphgen = graphgen.gabriel,
	}

	local numrooms = table.count(level.rooms)

	local actors = {}

	for _, room in pairs(level.rooms) do
		local vertex = table.random(room.vertices)
		assert(vertex)

		local actor = Actor.new(level, vertex, string.char(64 + #actors))

		actors[#actors+1] = actor
	end

	local scheduler = Scheduler.new()

	scheduler:add(
		function ()
			if playerAction then
				local cost, action = playerAction.cost, playerAction.action
				playerAction = nil
				return cost, action
			end

			return 0, nil
		end)

	for i = 2, #actors do
		local actor = actors[i]

		scheduler:add(
			function ()
				local dir = table.random(Level.Dir)
				local target = actor.vertex.dirs[dir]

				if not target or target.actor then
					return action.search(level, actor)
				else
					return action.move(level, actor, target)
				end
			end)
	end

	return level, actors, scheduler
end

local level, actors, scheduler = _gen()
local actions = {}
local warp = 1

gamemode = {}

function gamemode.update()
	local isDown = love.keyboard.isDown

	local camdx = (isDown('left') and -1 or 0) + (isDown('right') and 1 or 0)
	local camdy = (isDown('up') and -1 or 0) + (isDown('down') and 1 or 0)

	local dt = warp * love.timer.getDelta()
	
	camx = camx + (500 * dt * camdx)
	camy = camy + (500 * dt * camdy)

	if #actions == 0 then
		local complete, ticks = false, 0
		complete, ticks, actions = scheduler:run()
		-- print('run', ticks)
		
		for _, action in ipairs(actions) do
			action.time = 0
		end
	else
		local action = actions[1]

		-- print('actions', #actions)

		if action.sync then
			local running = action.plan(action.time)

			-- print('sync', running)

			if running then
				action.time = action.time + dt
			else
				table.remove(actions, 1)
			end
		else
			local index = 1

			while index <= #actions and not actions[index].sync do
				local action = actions[index]
				local running = action.plan(action.time)

				-- print('not sync', index, action.time)

				if running then
					index = index + 1

					action.time = action.time + dt
				else
					table.remove(actions, index)
				end
			end
		end
	end
end

local zoomed = true
local drawBoxes = false

local unknown = { 0, 0, 0, 255 }
local known = { 0, 45, 0, 255 }

local function _drawKDTree( kdtree, aabb )
	if kdtree.horz then
		love.graphics.line(kdtree.axis, aabb.ymin, kdtree.axis, aabb.ymax)
	else
		love.graphics.line(aabb.xmin, kdtree.axis, aabb.xmax, kdtree.axis)
	end

	local branch1 = kdtree[1]
	local branch2 = kdtree[2]

	if branch1 and branch1.horz ~= nil then
		local aabb = AABB.new(aabb)

		if kdtree.horz then
			aabb.xmax = kdtree.axis
		else
			aabb.ymax = kdtree.axis
		end

		_drawKDTree(branch1, aabb)
	end

	if branch2 and branch2.horz ~= nil then
		local aabb = AABB.new(aabb)

		if kdtree.horz then
			aabb.xmin = kdtree.axis
		else
			aabb.ymin = kdtree.axis
		end

		_drawKDTree(branch2, aabb)
	end
end

local canvas = love.graphics.newCanvas()
local clut =
	(function ()
		-- No official colour names.
		local lilac = { 132, 83, 255, 255 }
		local verdant = { 22, 178, 39, 255 }
		local drygrass = { 57, 255, 79, 255 }
		local clay = { 204, 114, 25, 255 }
		local sandysoil = { 178, 104, 31, 255 }

		local blur = 5
		local b1 = 25
		local b2 = 35
		local b3 = 50
		local b4 = 80

		local bands = {
			[1] = lilac,
			[b1-blur] = lilac,
			[b1+blur] = verdant,
			[b2-blur] = verdant,
			[b2+blur] = drygrass,
			[b3-blur] = drygrass,
			[b3+blur] = clay,
			[b4-blur] = clay,
			[b4+blur] = sandysoil,
			[100] = sandysoil,
		}

		return texture.bandedCLUT(bands, 256, 256)
	end)()

local mound = texture.mound(256, 256)

local moundEffect = love.graphics.newPixelEffect [[
	extern Image clut;

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
	{
		vec2 p = Texel(tex, tc).yx;

		return Texel(clut, p);
	}
]]

local drawEdges = true
local drawVertices = false
local drawMetalines = false
local drawMounds = true
local drawHeightfield = false

function gamemode.draw()
	love.graphics.push()
	
	local xform = {
		scale = { 1, 1 },
		translate = { 0, 0 },
	}

	if zoomed then
		xform.scale = { 1/3, 1/3 }
		xform.translate = { 800, 600 }
	else
		if track then
			camx, camy = actors[1][1] - (w * 0.5), actors[1][2] - (h * 0.5)
		end

		xform.translate = { -camx, -camy }
	end

	love.graphics.scale(xform.scale[1], xform.scale[2])
	love.graphics.translate(xform.translate[1], xform.translate[2])

	-- LoS and FoW
	local maxdepth = 3
	local distances = level:distanceMap(actors[1].vertex, maxdepth)

	for vertex, distance in pairs(distances) do
		vertex.known = true
	end

	local width = 50

	-- Metalines
	local count = 0

	if drawMetalines then
		local point1s, point2s = level:points()
		
		local intensities = {}

		for edge, endverts in pairs(level.graph.edges) do
			local vertex1, vertex2 = endverts[1], endverts[2]

			local intensity1 = vertex1.known and 0.05 or 0
			local intensity2 = vertex2.known and 0.05 or 0

			local distance1 = distances[vertex1]
			local distance2 = distances[vertex2]

			if distance1 then
				intensity1 = 0.5 + (maxdepth - distance1) / (maxdepth * 2)
				-- intensity1 = 1
			end

			if distance2 then
				intensity2 = 0.25 + (maxdepth - distance2) / (maxdepth * 2.5)
				-- intensity2 = 1
			end

			intensities[#intensities+1] = { intensity1, intensity2 }
		end

		count = metalines.draw(canvas, xform, w, h, point1s, point2s, intensities, width, clut)
	end

	if drawMounds then
		local oldBlendMode = love.graphics.getBlendMode()
		
		canvas:clear()
		love.graphics.setCanvas(canvas)
		
		love.graphics.setBlendMode('additive')
		love.graphics.setColor(255, 255, 255, 255)
		-- love.graphics.setColorMode('modulate')

		local colour = { 255, 255, 255, 255 }

		for vertex, peers in pairs(level.graph.vertices) do
			local maxEdgeLength = 0

			for peer, edge in pairs(peers) do
				maxEdgeLength = math.max(edge.length, maxEdgeLength)
			end

			local intensity = vertex.known and 0.25 or 0
			local distance = distances[vertex]
		
			if distance then
				-- intensity = 0.5 + (maxdepth - distance) / (maxdepth * 2)
				intensity = 1
			end

			colour[2] = math.round(intensity * 255)

			love.graphics.setColor(colour)

			local scale = (1.75 * maxEdgeLength) / 256
			love.graphics.draw(mound, vertex[1] - 128 * scale, vertex[2] - 128 * scale, 0, scale, scale)
			
			count = count + 1
		end

		love.graphics.setCanvas()

		local vpx = -xform.translate[1]
		local vpy = -xform.translate[2]
		local vpsx = 1/xform.scale[1]
		local vpsy = 1/xform.scale[2]

		if not drawHeightfield then
			moundEffect:send('clut', clut)
			love.graphics.setPixelEffect(moundEffect)
		end

		-- love.graphics.setBlendMode('alpha')
		love.graphics.draw(canvas, vpx, vpy, 0, vpsx, vpsy)

		if not drawHeightfield then
			love.graphics.setPixelEffect()
		end

		love.graphics.setBlendMode(oldBlendMode)
	end

	local linewidth = 2

	if drawEdges then
		love.graphics.setColor(128, 128, 128)
		love.graphics.setLine(linewidth, 'rough')

		-- local lines = {}

		for edge, verts  in pairs(level.graph.edges) do
			local vertex1 = verts[1]
			local vertex2 = verts[2]

			if vertex1.known and vertex2.known then
				local distance1 = distances[vertex1] or maxdepth + 1
				local distance2 = distances[vertex2] or maxdepth + 1
				local distance = math.max(distance1, distance2)

				local bias = (maxdepth - distance) / maxdepth
				local luminance = 100 + math.round(100 * bias)
				love.graphics.setColor(luminance, luminance, luminance)
				
				love.graphics.line(vertex1[1], vertex1[2], vertex2[1], vertex2[2])
				-- lines[#lines+1] = vertex1[1]
				-- lines[#lines+1] = vertex1[2]
				-- lines[#lines+1] = vertex2[1]
				-- lines[#lines+1] = vertex2[2]
			end
		end

		-- love.graphics.line(lines)
	end


	-- printf('#distances:%d', table.count(distances))
	if drawVertices then
		for vertex, _ in pairs(level.graph.vertices) do
			-- local radius = (vertex.subdivide) and linewidth * 1.5 or linewidth * 1.25
			local distance = distances[vertex]
			
			if distance then
				local bias = (maxdepth - distance) / maxdepth
				local luminance = 100 + math.round(100 * bias)
				love.graphics.setColor(luminance, luminance, luminance)
			else
				love.graphics.setColor(vertex.known and known or unknown)
			end

			local radius = linewidth
			love.graphics.circle('fill', vertex[1], vertex[2], radius)
		end
	end

	love.graphics.setColor(255, 255, 255)

	if drawBoxes then
		love.graphics.setLineWidth(3)
		for _, bbox in ipairs(level.boxes) do
			love.graphics.rectangle('line', bbox.xmin, bbox.ymin, bbox:width(), bbox:height())
		end
	end


	for _, actor in ipairs(actors) do
		if distances[actor.vertex] then
			local vx, vy = actor[1], actor[2]
			local dx, dy = font:getWidth(actor.symbol) * 0.5, font:getHeight() * 0.5
			local x, y = vx - dx, vy - dy

			love.graphics.setColor(0, 0, 0)

			love.graphics.print(actor.symbol, x - 1, y - 1)
			love.graphics.print(actor.symbol, x - 1, y + 1)
			love.graphics.print(actor.symbol, x + 1, y - 1)
			love.graphics.print(actor.symbol, x + 1, y + 1)

			love.graphics.setColor(255, 255, 255)

			love.graphics.print(actor.symbol, x, y)
		end
	end

	local points = {}

	for vertex, _ in pairs(level.graph.vertices) do
		points[#points+1] = Vector.new(vertex)
	end

	local kdtree = KDTree.new(points)

	love.graphics.setLineWidth(1)
	love.graphics.setColor(0, 0, 255)

	-- _drawKDTree(kdtree, level.aabb)

	love.graphics.pop()

	local numVertices = table.count(level.graph.vertices)
	local numEdges = table.count(level.graph.edges)

	local text = string.format('warp:%.2f fps:%.2f #v:%d #e:%d #ml:%d',
		warp,
		love.timer.getFPS(),
		numVertices,
		numEdges,
		count)

	love.graphics.print(text, 10, 10)
end

function gamemode.mousepressed( x, y, button )
end

local Dir = Level.Dir

local _keydir = {
	h = Dir.W,
	j = Dir.S,
	k = Dir.N,
	l = Dir.E,
	y = Dir.NW,
	u = Dir.NE,
	b = Dir.SW,
	n = Dir.SE,

	kp1 = Dir.SW,
	kp2 = Dir.S,
	kp3 = Dir.SE,
	kp4 = Dir.W,
	kp6 = Dir.E,
	kp7 = Dir.NW,
	kp8 = Dir.N,
	kp9 = Dir.NE,
}

local known = false

function gamemode.keypressed( key )
	if key == 'z' then
		zoomed = not zoomed
	elseif key == 'a' then
		drawBoxes = not drawBoxes
	elseif key == ' ' then
		level, actors, scheduler = _gen()
		actions = {}
	elseif key == 's' and not playerAction and #actions == 0 then
		local cost, action = action.search(level, actors[1])

		playerAction = {
			cost = cost,
			action = action,
		}
	elseif key == 'v' then
		drawVertices = not drawVertices
	elseif key == 'e' then
		drawEdges = not drawEdges
	elseif key == 'm' then
		drawMetalines = not drawMetalines
	elseif key == 'x' then
		drawMounds = not drawMounds
	elseif key == 'd' then
		drawHeightfield = not drawHeightfield
	elseif key == 't' then
		track = not track
	elseif key == 'right' then
		warp = math.min(warp * 2, 1024)
	elseif key == 'left' then
		warp = math.max(warp * 0.5, 1 / 1024)
	elseif key == 'f' then
		known = not known

		for vertex, _ in pairs(level.graph.vertices) do
			vertex.known = known
		end
	elseif not playerAction and #actions == 0 then
		local dir = _keydir[key]
		local player = actors[1]
		local target = player.vertex.dirs[dir]

		if dir and target and not target.actor then
			local cost, action = action.move(level, player, target)

			playerAction = {
				cost = cost,
				action = action,
			}
		end
	end
end

function gamemode.keyreleased( key )
end
