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
require 'metalines'
require 'texture'
require 'Voronoi'

local w, h = love.graphics.getWidth(), love.graphics.getHeight()
local track = false
local actions = {}
local playerAction = nil
local diagram = nil


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
		-- margin = 100,
		margin = 50,
		-- margin = 75,
		-- margin = 100,
		layout = layoutgen.splat,
		roomgen = rgen,
	}

	
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
end

local drawPoints = true
local drawRoomAABBs = true
local drawQuadtree = true

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

function voronoimode.draw()
	love.graphics.push()
	
	local xform = {
		scale = scale,
		origin = { 0, 0 },
	}
	
	love.graphics.translate(-xform.origin[1], -xform.origin[2])
	love.graphics.scale(xform.scale, xform.scale)

	if drawQuadtree then
		love.graphics.setColor(0, 0, 255, 255)
		local old = love.graphics.getBlendMode()
		love.graphics.setBlendMode('additive')

		local function aux( node )
			local leaf = true

			for i = 1, 4 do
				local child = node[i]
				if child then
					aux(child)
					leaf = false
				end
			end

			-- if leaf then
				local aabb = node.aabb
				love.graphics.rectangle('line', aabb.xmin, aabb.ymin, aabb:width(), aabb:height())
			-- end
		end

		local root = level.quadtree.root
		if root then
			aux(root)
		end

		love.graphics.setBlendMode(old)
	end

	if drawRoomAABBs then
		love.graphics.setLineWidth(3)
		love.graphics.setColor(0, 255, 0, 255)

		for index, room in ipairs(level.rooms) do
			local aabb = room.aabb
			love.graphics.rectangle('line', aabb.xmin, aabb.ymin, aabb:width(), aabb:height())
		end
	end

	if drawPoints then
		love.graphics.setColor(255, 0 , 255, 255)

		for index, room in ipairs(level.rooms) do
			for _, point in ipairs(room.points) do
				local radius = 2
				love.graphics.circle('fill', point[1], point[2], radius)	
			end
		end
	end

	love.graphics.pop()

	local numPoints = 0

	for index, room in ipairs(level.rooms) do
		numPoints = numPoints + #room.points
	end

	shadowf(10, 10, 'fps:%.2f #p:%d',
		love.timer.getFPS(),
		numPoints)
end

function voronoimode.mousepressed( x, y, button )
	if button == 'wu' then
		scale = math.min(3, scale * 3)
		printf('scale:%.2f', scale)
	elseif button == 'wd' then
		scale = math.max(1/3, scale * 1/3)
		printf('scale:%.2f', scale)
	end
end

local function genvoronoi()
	if diagram then
		diagram = nil
	else
		local sites = {}

		for vertex, _ in pairs(level.graph.vertices) do
			local site = {
				x = vertex[1],
				y = vertex[2],
				wall = vertex.wall,
			}
			sites[#sites+1] = site
		end

		local bbox = {
			xl = level.aabb.xmin - 100,
			xr = level.aabb.xmax + 100,
			yt = level.aabb.ymin - 100,
			yb = level.aabb.ymax + 100,
		}

		local start = love.timer.getMicroTime()
		diagram = Voronoi:new():compute(sites, bbox)
		local finish = love.timer.getMicroTime()

		printf('Voronoi:compute(%d) %.3fs', #sites, finish - start)

		-- print('bbox', bbox.xl, bbox.xr, bbox.yt, bbox.yb)
		-- print('#cells', #diagram.cells)
		-- print('#edges', #diagram.edges)

		-- for index, cell in ipairs(diagram.cells) do
		-- 	print('cell', index, '#halfedges', #cell.halfedges)
		-- end
	end
end

function voronoimode.keypressed( key )
	if key == 'z' then
		if scale ~= 1/3 then
			scale = 1/3
		else
			scale = 1
		end
	elseif key == 'a' then
		drawRoomAABBs = not drawRoomAABBs
	elseif key == ' ' then
		level = _gen()
	end
end

function voronoimode.keyreleased( key )
end
