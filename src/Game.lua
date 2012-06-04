require 'misc'
require 'Level'
require 'Actor'
require 'Scheduler'
require 'roomgen'
require 'layoutgen'

Game = {}
Game.__index = Game

local function _gen()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()

	local rgen =
		function ( ... )
			local r = math.random()
			if r < 0.33 then
				return roomgen.browniangrid(...)
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

	return level, actors
end

function Game.new()
	local level, actors = _gen()
	local scheduler = Scheduler.new()

	local result = {
		level = level,
		scheduler = nil,
		actors = nil,
		player = nil
		actions = nil,
	}

	setmetatable(result, Game)



	return result
end

function Game:update()
	-- if not waiting for player input
	-- 


end
