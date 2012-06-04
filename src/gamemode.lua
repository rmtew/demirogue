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

gamemode = {}

function gamemode.update()
	local isDown = love.keyboard.isDown

	local camdx = (isDown('left') and -1 or 0) + (isDown('right') and 1 or 0)
	local camdy = (isDown('up') and -1 or 0) + (isDown('down') and 1 or 0)

	local dt = love.timer.getDelta()
	
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
				action.time = action.time + love.timer.getDelta()
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

					action.time = action.time + love.timer.getDelta()
				else
					table.remove(actions, index)
				end
			end
		end
	end
end

local zoomed = true
local boxes = false

function gamemode.draw()
	love.graphics.push()
	
	if zoomed then
		love.graphics.scale(1/3, 1/3)
		love.graphics.translate(800, 600)
	else
		if track then
			camx, camy = actors[1][1] - (w * 0.5), actors[1][2] - (h * 0.5)
		end

		love.graphics.translate(-camx, -camy)
	end

	local linewidth = 6
	love.graphics.setLineWidth(linewidth)

	love.graphics.setColor(128, 128, 128)

	for edge, verts  in pairs(level.graph.edges) do
		local vertex1 = verts[1]
		local vertex2 = verts[2]

		love.graphics.line(vertex1[1], vertex1[2], vertex2[1], vertex2[2])
	end

	love.graphics.setColor(191, 191, 191)

	for point, _ in pairs(level.graph.vertices) do
		local radius = (point.subdivide) and linewidth * 1.5 or linewidth * 1.25
		love.graphics.circle('fill', point[1], point[2], radius)
	end

	love.graphics.setColor(255, 255, 255)

	if boxes then
		love.graphics.setLineWidth(1)
		for _, bbox in ipairs(level.boxes) do
			love.graphics.rectangle('line', bbox.xmin, bbox.ymin, bbox:width(), bbox:height())
		end
	end


	for _, actor in ipairs(actors) do
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

	love.graphics.pop()
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

function gamemode.keypressed( key )
	if key == 'z' then
		zoomed = not zoomed
	elseif key == 'a' then
		boxes = not boxes
	elseif key == ' ' then
		level, actors, scheduler = _gen()
		actions = {}
	elseif key == 's' then
		for _, actor in ipairs(actors) do
			local dir = table.random(actor.vertex.dirs)

			local success = actor:move(dir)
		end
	elseif key == 't' then
		track = not track
	elseif not playerAction then
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
