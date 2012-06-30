require 'misc'
require 'Vector'
require 'AABB'
require 'graphgen'
require 'layoutgen'
require 'roomgen'
require 'Level'
require 'Actor'
require 'Scheduler'
require 'behaviour'
require 'action'
require 'KDTree'
require 'metalines'
require 'texture'

local w, h = love.graphics.getWidth(), love.graphics.getHeight()
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
			xmin = 0,
			ymin = 0,
			xmax = 3 * w,
			ymax = 3 * h,
		},
		margin = 100,
		-- margin = 50,
		-- margin = 75,
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

		local onDeath =
			function ( victim )
				print('onDeath')
				for index, actor in ipairs(actors) do
					if actor == victim then
						print('index', index)
						table.remove(actors, index)

						break
					end
				end
			end

		local actor = Actor.new(level, vertex, string.char(64 + #actors), onDeath)

		if math.random() >= 0.5 then
			actor.anim =
				function ( time )
					local x = 0
					local y = 10 + (5 * math.sin(time * math.pi))

					return x, -y
				end
			actor.shadow = true
		end

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

	for _, node in pairs(behaviour.nodes) do
		_G['AI_' .. node.tag] = 
			function ( tbl )
				tbl.tag = node.tag
				return tbl
			end
	end

	local aiParams = 
		AI_Priority {
			AI_Wander {},
			AI_Search {},
		}

	for _, node in pairs(behaviour.nodes) do
		_G['AI_' .. node.tag] = nil
	end

	for i = 2, #actors do
		local actor = actors[i]

		local ai = behaviour.new(aiParams)

		local job = scheduler:add(
			function ()
				local result, cost, plan = ai:tick(level, actor)

				if result == behaviour.Result.PERFORM then
					return cost, plan
				else
					return 1, nil
				end
			end)

		actor.job = job
	end

	return level, actors, scheduler
end

local level, actors, scheduler = _gen()
local actions = {}
local warp = 1
local time = 0

gamemode = {}

function gamemode.update()
	local dt = warp * love.timer.getDelta()
	time = time + dt

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
		-- Non official colour names.
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

		-- This is a test of black with a white edge for an old-school vibe.
		--
		-- local blur = 5
		-- local b1 = 10
		-- local b2 = 30
	
		-- local black = { 0, 0, 0, 255 }
		-- local white = { 255, 255, 255, 255 }

		-- local bands = {
		-- 	[1] = black,
		-- 	[b1-blur] = white,
		-- 	[b1+blur] = white,
		-- 	[b2-blur] = black,
		-- 	[100] = black,
		-- }

		return texture.bandedCLUT(bands, 256, 256, 'grey')
	end)()

local mound = texture.mound(256, 256)
local blobs = love.graphics.newImage('resources/blobs.png')
local bricks = love.graphics.newImage('resources/bricks.png')
local crystal = love.graphics.newImage('resources/crystal.png')
local triforce = love.graphics.newImage('resources/triforce.png')
local grass = love.graphics.newImage('resources/grass.png')

local backlight = texture.featheredCircle(256, 256, 0, 255, 0, 255, 0.85)
local forelight = texture.smootherCircle(256, 256, 0, 0, 255, 255, 0.5)

local lofi = love.graphics.newImage('resources/lofi_char-rgba-x8.png')

function quads( x, y, width, height, numx, numy )
	local result = {}
	for xth = 0, numx-1 do
		for yth = 0, numy-1 do
			result[#result+1] = love.graphics.newQuad(
				x + xth * width,
				y + yth * height,
				width,
				height,
				lofi:getWidth(),
				lofi:getHeight())
		end
	end
	return result
end

local t = 64
local t2 = 128

local players = {
	heroes		= quads(0, 0, t, t, 16, 1),
	heroines	= quads(0, 1 * t, t, t, 16, 1),
	humanoids	= quads(0, 2 * t, t, t, 16, 1),
	elves		= quads(0, 3 * t, t, t, 16, 1),
	dwarves		= quads(0, 4 * t, t, t, 16, 1),
}

local monsters = {
	goblins		= quads(0, 5 * t, t, t, 16, 1),
	undead		= quads(0, 6 * t, t, t, 16, 1),
	spirits		= quads(0, 7 * t, t, t, 16, 1),
	ogres		= quads(0, 8 * t, t, t, 16, 1),
	magical		= quads(0, 9 * t, t, t, 16, 1),
	golems		= quads(0, 10 * t, t, t, 16, 1),
	creature	= quads(0, 11 * t, t, t, 16, 1),
	critters	= quads(0, 12 * t, t, t, 16, 1),
	animals		= quads(0, 13 * t, t, t, 16, 1),
	whelps		= quads(0, 14 * t, t, t, 16, 1),
	dragons		= quads(0, 15 * t, t2, t, 8, 1),
	legends		= quads(0, 16 * t, t2, t2, 8, 3),
}

function export()
	local base = love.image.newImageData('resources/lofi_char-rgba-x8.png')

	local combined = {}

	for name, quads in pairs(players) do
		combined[name] = quads
	end

	for name, quads in pairs(monsters) do
		combined[name] = quads
	end

	for name, quads in pairs(combined) do
		for index, quad in ipairs(quads) do
			local qx, qy, qw, qh = quad:getViewport()
			local border = 4
			local bw, bh = qw + 2 * border, qh + 2 * border

			local image = love.image.newImageData(bw, bh)
			local mask = {}

			for i = 0, bw-1 do
				local row = {}
				for j = 0, bh-1 do
					row[j] = false
				end
				mask[i] = row
			end 

			image:mapPixel(
				function ( x, y )
					local inx = border <= x and x < qw + border
					local iny = border <= y and y < qh + border

					if inx and iny then
						local r, g, b, a = base:getPixel(qx + x - border, qy + y - border)

						if a > 0 then
							mask[x][y] = true
						end

						return r, g, b, a
					else
						return 0, 0, 0, 0
					end
				end)

			--[[
			image:mapPixel(
				function ( x, y, r, g, b, a )
					if x == 0 or x == bw-1 or y == 0 or y == bh-1 then
						return 0, 0, 0, 255
					end

					return r, g, b, a
				end)
			--]]

			---[[
			image:mapPixel(
				function ( x, y, r, g, b, a )
					if r ~= 0 or g ~= 0 or b ~= 0 or a ~= 0 then
						return r, g, b, a
					end

					for dx = math.max(0, x-2), math.min(bw-1, x+2) do
						for dy = math.max(0, y-2), math.min(bh-1, y+2) do
							if mask[dx][dy] then
								return 0, 0, 0, 128
							end
						end
					end

					return 0, 0, 0, 0
				end)
			--]]

			image:encode(string.format('%s-%02d.png', name, index))
		end
	end
end

-- export()

for name, quads in pairs(players) do
	for index, quad in ipairs(quads) do
		local image = love.graphics.newImage(string.format('%s-%02d.png', name, index))
		quads[index] = image
	end
end

for name, quads in pairs(monsters) do
	for index, quad in ipairs(quads) do
		local image = love.graphics.newImage(string.format('%s-%02d.png', name, index))
		quads[index] = image
	end
end

-- local backlight = love.graphics.newImage('resources/blobs-g.png')
-- local forelight = love.graphics.newImage('resources/blobs-b.png')

local heightEffect = love.graphics.newPixelEffect [[
	extern Image clut;

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
	{
		vec3 p = Texel(tex, tc).xyz;
		float h = p.x;
		float l = (0.25 * p.g) + (0.75 * p.b);

		return Texel(clut, vec2(l, h));
	}
]]

local coverEffect = love.graphics.newPixelEffect [[
	// The height and light canvas.
	extern Image height;
	// The height band the cover will be drawn in.
	extern float minHeight;
	extern float maxHeight;

	/*float smooth(float x, float minx, float maxx)
	{
		float n = clamp((x - minx) / (maxx - minx), 0, 1);

		return n*n*n*(n*(n*6 - 15) + 10);
	}*/

	/*float smooth(float x, float minx, float maxx)
	{
		float n = clamp((x - minx) / (maxx - minx), 0, 1);
		float ns = 2 * n - 1;

		return -(ns*ns) + 1;
	}*/

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
	{
		vec4 hl = Texel(height, pc / vec2(800.0, 600.0));
		float h = hl.r;
		float l = (0.25 * hl.g) + (0.75 * hl.b);
		// This is 1 when minHeight <= h <= maxHeight and 0 otherwise.
		// float band = (1 - step(h, minHeight)) * (1 - step(maxHeight, h));
		// float band = smooth(h, minHeight, maxHeight);
		float band = (1 - step(h, minHeight)) * (step(minHeight, maxHeight));
		vec4 lv = vec4(l ,l ,l, band);

		vec4 p = Texel(tex, tc);


		// Light and band check the texel.
		p *= lv;

		return p;
	}
]]

local drawEdges = true
local drawVertices = true
local drawMetalines = false
local drawMounds = true
local drawHeightfield = false
local drawCover = true
local drawBetweeness = false
local drawOryx = false

local _spriteBatches = {}

local function _getSpriteBatches( batches )
	local result = {}

	for name, params in pairs(batches) do
		local spriteBatch = _spriteBatches[name]

		-- TODO: should also check whether the images are the same.
		if not spriteBatch or spriteBatch.size < params.size then
			spriteBatch = {
				batch = love.graphics.newSpriteBatch(params.image, params.size),
				size = params.size
			}

			_spriteBatches[name] = spriteBatch
		end

		result[name] = spriteBatch
	end

	return result
end

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

local scale = 1/3

function gamemode.draw()
	love.graphics.push()
	
	local xform = {
		scale = scale,
		origin = { 0, 0 },
	}
	
	if track then		
		xform.origin = {
			(actors[1][1] * xform.scale) - (0.5 * w),
			(actors[1][2] * xform.scale) - (0.5 * h),
		}
	end

	-- love.graphics.translate(xform.origin[1] + w * 0.5, xform.origin[2] + h * 0.5)
	love.graphics.translate(-xform.origin[1], -xform.origin[2])
	love.graphics.scale(xform.scale, xform.scale)

	-- LoS and FoW
	--
	-- Three state FoW unknown, known and not in LoS and known and in LoS.
	-- The known flag is stored on the vertices as a boolean or nil and the
	-- distances table is the LoS.
	local maxdepth = 2
	-- local maxdepth = math.min(4, table.count(actors[1].vertex.dirs) - 1)
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
		local numVertices = table.count(level.graph.vertices)
		local numSeenVertices = table.count(distances)
		
		local batches = _getSpriteBatches {
			height = {
				-- image = triforce,
				-- image = crystal,
				-- image = bricks,
				image = blobs,
				-- image = mound,
				size = numVertices,
			},
			backlight = {
				image = backlight,
				size = numVertices,
			},
			forelight = {
				image = forelight,
				size = numVertices,
			},
			grass = {
				image = grass,
				size = numVertices,
			}
		}

		local heightBatch = batches.height.batch
		local backlightBatch = batches.backlight.batch
		local forelightBatch = batches.forelight.batch
		local grassBatch = batches.grass.batch

		for name, data in pairs(batches) do
			data.batch:clear()
			data.batch:bind()
		end

		for vertex, peers in pairs(level.graph.vertices) do
			local maxEdgeLength = 0

			for peer, edge in pairs(peers) do
				maxEdgeLength = math.max(edge.length, maxEdgeLength)
			end

			-- TThe first number here is a bit of a magic number I've arrived
			-- at by trial and error. It's specific to the height texture being
			-- used.
			local scale = (1.5 * maxEdgeLength) / 256
			local x = vertex[1]
			local y = vertex[2]
			local rot = vertex.rot
			local grass = vertex.grass

			if not rot then
				rot = math.random() * math.pi * 2
				vertex.rot = rot
			end

			if grass == nil then
				grass = math.random(1, 3) == 1
				vertex.grass = grass
			end

			heightBatch:add(x, y, rot, scale, scale, 128, 128)

			if grass then
				grassBatch:add(x, y, rot, scale, scale, 128, 128)
			end

			-- Height textures aren't required to fit with a circle like the
			-- light texture does so enlarging by sqrt(2) should be enough to
			-- contain them.
			local scale = scale * math.sqrt(2)

			if vertex.known then
				backlightBatch:add(x, y, rot, scale, scale, 128, 128)
			end

			local distance = distances[vertex]
		
			if distance then
				-- distance [0..maxdepth] -> normed [1..0]
				local normed = (maxdepth - distance) / maxdepth
				local g = 255 * (0.75 + 0.25 * normed)
				
				-- The forelight is in the b component.
				-- forelightBatch:setColor(0, 0, g, 255)
				forelightBatch:add(x, y, rot, scale, scale, 128, 128)
			end
			
			count = count + 1
		end

		for name, data in pairs(batches) do
			data.batch:unbind()
		end

		local oldBlendMode = love.graphics.getBlendMode()
		
		canvas:clear()
		love.graphics.setCanvas(canvas)
		
		love.graphics.setBlendMode('additive')
		-- The backlight is rendered to the g component at half strength.
		love.graphics.setColor(0, 255, 0, 255)
		love.graphics.draw(backlightBatch, 0, 0)

		-- The forelight is rendered to the b component.
		love.graphics.setColor(0, 0, 255, 255)
		love.graphics.draw(forelightBatch, 0, 0)

		-- Heights are rendered to the r component.
		love.graphics.setColor(255, 0, 0, 255)
		love.graphics.draw(heightBatch, 0, 0)
		
		love.graphics.setCanvas()

		if not drawHeightfield then
			heightEffect:send('clut', clut)
			love.graphics.setPixelEffect(heightEffect)
		end
		
		-- TODO: this is also used else where, refactor xfrom to create them.
		local vpx = xform.origin[1] * 1/xform.scale
		local vpy = xform.origin[2] * 1/xform.scale
		local vpsx = 1/xform.scale
		local vpsy = 1/xform.scale

		love.graphics.setColor(255, 255, 255, 255)
	
		love.graphics.draw(canvas, vpx, vpy, 0, vpsx, vpsy)

		if not drawHeightfield then
			love.graphics.setPixelEffect()
		end

		if drawCover then
			-- TODO: the min and max heights should be specified in a theme.
			coverEffect:send('height', canvas)
			coverEffect:send('minHeight', 0.8)
			coverEffect:send('maxHeight', 1)

			love.graphics.setPixelEffect(coverEffect)

			love.graphics.setBlendMode('alpha')
			love.graphics.draw(grassBatch, 0, 0)

			love.graphics.setPixelEffect()
		end

		love.graphics.setBlendMode(oldBlendMode)
	end

	local linewidth = 2

	if drawEdges then
		love.graphics.setColor(128, 128, 128)
		love.graphics.setLine(linewidth * 1/xform.scale, 'rough')

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
				love.graphics.setColor(luminance, 0, luminance, luminance)
				
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
				love.graphics.setColor(luminance, 0, luminance, luminance)
			else
				love.graphics.setColor(vertex.known and known or unknown)
			end

			local radius = linewidth + 1
			love.graphics.circle('fill', vertex[1], vertex[2], radius)
		end
	end

	if drawBetweeness then
		if not level.betweenness then
			level.betweenness = level.graph:betweenness()
			for vertex, value in pairs(level.betweenness) do
				print(value)
			end
		end

		love.graphics.setColor(255, 255, 255, 255)

		for vertex, value in pairs(level.betweenness) do
			love.graphics.setColor(255, 255, 255, 255)
			local radius = 30
			love.graphics.circle('fill', vertex[1], vertex[2], radius)

			love.graphics.setColor(0, 0, 0, 255)
			love.graphics.arc('fill', vertex[1], vertex[2], radius * 0.9, 0, value * math.pi * 2)

			if vertex.centrality then
				love.graphics.setColor(255, 0, 255, 255)
				love.graphics.arc('fill', vertex[1], vertex[2], radius * 0.6, 0, vertex.centrality * math.pi * 2)
			end

			love.graphics.setColor(128, 192, 128, 255)

			if vertex.central then
				love.graphics.setColor(255, 0, 0, 255)
				love.graphics.arc('fill', vertex[1], vertex[2], radius * 0.3, 0, math.pi)
			end

			if vertex.peripheral then
				love.graphics.setColor(0, 0, 255, 255)
				love.graphics.arc('fill', vertex[1], vertex[2], radius * 0.3, math.pi, 2 * math.pi)
			end
		end
	end

	love.graphics.setColor(255, 255, 255)

	if drawBoxes then
		love.graphics.setLineWidth(3)
		for _, bbox in ipairs(level.boxes) do
			love.graphics.rectangle('line', bbox.xmin, bbox.ymin, bbox:width(), bbox:height())
		end

		local st = math.abs(math.sin(time))
		local ct = math.abs(math.cos(time))
		love.graphics.setColor(st * 255, ct * 255, 255, 255)

		for _, bbox in ipairs(level.aabbs) do
			love.graphics.rectangle('line', bbox.xmin, bbox.ymin, bbox:width(), bbox:height())
		end
	end

	local nullanim = function () return 0, 0 end

	for index, actor in ipairs(actors) do
		if distances[actor.vertex] then
			local vx, vy = actor[1], actor[2]
			local ox, oy = actor.offset[1], actor.offset[2]
			local anix, aniy = 0, 0

			if actor.anim then
				anix, aniy = actor.anim(time)
			end

			local ax, ay = (actor.anim or nullanim)(time)
			
			if not drawOryx then
				local dx, dy = font:getWidth(actor.symbol) * 0.5, font:getHeight() * 0.5
				local x, y = (vx + ox) - dx, (vy + oy) - dy

				shadowf(x, y, actor.symbol)
			else
				local image = actor.image

				if not image then
					local set = (index == 1) and players or monsters
					local _, images = table.random(set)
					local _, choice = table.random(images)
					actor.image, image = choice, choice
				end

				local w, h = image:getWidth(), image:getHeight()

				local x = vx + ox + anix
				local y = vy + oy + aniy
				local sx = 0.5
				local sy = 0.5
				local offx = w * sx
				local offy = h * sy

				-- if actor.shadow then
				-- 	love.graphics.setColor(0, 0, 0, 255)
				-- 	love.graphics.draw(image, x, vy, 0, sx, sy * 0.2, offx, offy)
				-- end

				love.graphics.setColor(255, 255, 255, 255)
				love.graphics.draw(image, x, y, 0, sx, sy, offx, offy)
			end
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

	shadowf(10, 10, 'warp:%.2f fps:%.2f #v:%d #e:%d #ml:%d',
		warp,
		love.timer.getFPS(),
		numVertices,
		numEdges,
		count)
end

function gamemode.mousepressed( x, y, button )
	if button == 'wu' then
		scale = math.min(3, scale * 3)
		printf('scale:%.2f', scale)
	elseif button == 'wd' then
		scale = math.max(1/3, scale * 1/3)
		printf('scale:%.2f', scale)
	end
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
		if scale ~= 1/3 then
			scale = 1/3
			track = false
		else
			scale = 1
			track = true
		end
	elseif key == 'a' then
		drawBoxes = not drawBoxes
	elseif key == ' ' then
		level, actors, scheduler = _gen()
		actions = {}
		known = false
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
	elseif key == 'c' then
		drawCover = not drawCover
	elseif key == 'q' then
		drawBetweeness = not drawBetweeness
	elseif key == 'o' then
		drawOryx = not drawOryx

		if not drawOryx then
			for _, actor in ipairs(actors) do
				actor.image = nil
			end
		end
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

		if dir and target then
			if not target.actor then
				local cost, action = action.move(level, player, target)

				playerAction = {
					cost = cost,
					action = action,
				}
			else
				local cost, action = action.melee(level, player, target.actor)

				playerAction = {
					cost = cost,
					action = action,
				}
			end
		end
	end
end

function gamemode.keyreleased( key )
end
