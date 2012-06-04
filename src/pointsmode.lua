require 'Vector'
require 'AABB'
require 'graphgen'
require 'layoutgen'
require 'roomgen'
require 'Level'
require 'misc'

local dirty = true
local graph, count = Graph.new(), nil
local at = nil
local boxes = {}
local graphgenkey = 'gabriel'
local zoomed = false
local layoutgenkey = 'bsp'

pointsmode = {}

function pointsmode.update()
	if dirty then
		graph, count = graphgen[graphgenkey](table.keys(graph.vertices))

		dirty = false
	end
end

local roomgenkey = 'grid'

function pointsmode.draw()
	if zoomed then
		love.graphics.push()
		love.graphics.scale(1/3, 1/3)
		love.graphics.translate(800, 600)
	end

	local linewidth = 6
	love.graphics.setLineWidth(linewidth)

	love.graphics.setColor(128, 128, 128)

	for edge, verts  in pairs(graph.edges) do
		local point1 = verts[1]
		local point2 = verts[2]

		love.graphics.line(point1[1], point1[2], point2[1], point2[2])
	end

	love.graphics.setColor(191, 191, 191)

	for point, _ in ipairs(graph.vertices) do
		love.graphics.circle('fill', point[1], point[2], linewidth * 1.25)
	end

	love.graphics.setColor(255, 255, 255)

	local atpt = points[at]

	if atpt then
		love.graphics.print('@', atpt[1], atpt[2])
	end

	if boxes then
		love.graphics.setLineWidth(1)
		for _, bbox in ipairs(boxes) do
			love.graphics.rectangle('line', bbox.xmin, bbox.ymin, bbox:width(), bbox:height())
		end
	end

	if zoomed then
		love.graphics.pop()
	end

	love.graphics.print(string.format('#pts:%d #edges:%d count:%d roomgen:%s #box:%d', #points, #graph.edges or 0, count or 0, roomgenkey, #boxes or 0), 10, 10)
end

function pointsmode.mousepressed( x, y, button )
	for point, _ in pairs(graph.vertices) do
		if x == point[1] and y == point[2] then
			return
		end
	end

	graph:addVertex(Vector.new { x, y })
	dirty = true
end

function _move( at, dir )
	if not graph then
		return nil
	end

	local atpt = next(graph.vertices)

	if not atpt then
		return
	end

	local normdir = dir:normal()

	local peers = graph.vertices[at]

	-- This ensures we don't go too far off the intended direction.
	local maxdot = 0.5
	local result = nil

	for peer, _ in pairs(peers) do
		local disp = atpt:to(peer)

		local dot  = normdir:dot(disp:normal())

		if dot > maxdot then
			maxdot = dot
			result = peer
		end
	end

	return result
end

local _dirs = {
	h = { -1,  0 },
	j = {  0,  1 },
	k = {  0, -1 },
	l = {  1,  0 },
	y = { -1, -1 },
	u = {  1, -1 },
	b = { -1,  1 },
	n = {  1,  1 },
}


function pointsmode.keypressed( key )
	if key == 'delete' then
		graph = Graph.new()
		count = 0
		at = nil

		dirty = true
	elseif key == 'r' then
		for i = 1, 100 do
			graph:addVertex(Vector.new {
				math.random(1, love.graphics.getWidth()),
				math.random(1, love.graphics.getHeight())
			})
		end
		dirty = true
	elseif key == ' ' then
		roomgenkey = next(roomgen, roomgenkey) or next(roomgen)
	elseif key == 't' then
		graphgenkey = next(graphgen, graphgenkey) or next(graphgen)
		dirty = true
	elseif key == 'q' then
		layoutgenkey = next(layoutgen, layoutgenkey) or next(layoutgen)
	elseif key == 'z' then
		zoomed = not zoomed
	elseif key == 'd' then
		local w, h = love.graphics.getWidth(), love.graphics.getHeight()
		local bbox = AABB.new {
			xmin = -w,
			ymin = -h,
			xmax = 2 * w,
			ymax = 2 * h,
		}

		local limits = {
			minwidth = 100,
			minheight = 100,
			margin = 50,
			maxleaves = 45,
		}

		boxes = layoutgen[layoutgenkey](bbox, limits)

		points = {}
		graph = {
			edges = {},
			peers = {},
		}
		local edges = graph.edges
		local peers = graph.peers

		local roomgens = {}

		for _, func in pairs(roomgen) do
			roomgens[#roomgens+1] = func
		end

		for _, bbox in pairs(boxes) do
			--local rgen = roomgens[math.random(1, #roomgens)]
			local rgen = roomgen.browniangrid
			local ps = rgen(bbox, 50)
			local grp = graphgen[graphgenkey](ps)

			local offset = #points

			for _, p in ipairs(ps) do
				points[#points+1] = p
			end

			for _, edge in ipairs(grp.edges) do
				edges[#edges+1] = { edge[1] + offset, edge[2] + offset }
			end

			for src, set in ipairs(grp.peers) do
				local newset = {}

				for idx, _ in pairs(set) do
					newset[idx + offset] = true
				end

				peers[src+offset] = newset
			end
		end
	elseif key == 'g' then
		local bbox = {
			xmin = 100,
			ymin = 100,
			xmax = 400,
			ymax = 400
		}
		local margin = 50
		
		local room = roomgen[roomgenkey](bbox, margin)

		for _, point in ipairs(room) do
			points[#points+1] = point
		end

		dirty = true
	else
		local dir = _dirs[key]
		if dir then
			local newat = _move(at, Vector.new(dir))

			if newat then
				at = newat
			end
		end
	end
end

function pointsmode.keyreleased( key )
end
