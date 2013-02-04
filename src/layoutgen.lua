require 'AABB'

layoutgen = {}

local function table_pick( tbl, index )
	local result = tbl[index]
	
	tbl[index] = tbl[#tbl]
	tbl[#tbl] = nil

	return result
end

-- limits = {
--     minwidth = minimum width of a resulting bbox
--     minheight = minimum height of a resulting bbox
--     maxwidth = maximum width of a resulting bbox
--     maxheight = maximum height of a resulting bbox
--     margin = minimum space between resulting bboxes
--     maxboxes = maximum no. of resulting leaves.
-- }
--

local _axes = {
	'horz',
	'vert',
}

function layoutgen.bsp( bbox, limits )
	error('layoutgen.bsp() is very bad')

	local minbranchwidth = (2 * limits.minwidth) + (2 * limits.margin)
	local minbranchheight = (2 * limits.minheight) + (2 * limits.margin)

	local minleafwidth = limits.minwidth + limits.margin
	local minleafheight = limits.minheight + limits.margin

	-- A branch is an aabb that is big enough to be split.
	local branches = { bbox }
	-- A leaf is an aabb that can't be split without making it smaller than
	-- the limits allow.
	local leaves = {}

	while #branches > 0 and #branches + #leaves < limits.maxboxes do
		local branch = table_pick(branches, math.random(1, #branches))

		local horzsplit = branch:width() > minbranchwidth
		local vertsplit = branch:height() > minbranchheight

		if not horzsplit and not vertsplit then
			leaves[#leaves+1] = branch
		else
			local axis = _axes[math.random(horzsplit and 1 or 2, vertsplit and 2 or 1)]
			local coord = nil

			if axis == 'horz' then
				local min = branch.xmin + minleafwidth
				local max = branch.xmax - minleafwidth
				coord = math.random(min, max)
			else
				local min = branch.ymin + minleafheight
				local max = branch.ymax - minleafheight
				coord = math.random(min, max)
			end

			local sub1, sub2 = branch:split(axis, coord)

			if sub1:width() < minbranchwidth and sub1:height() < minbranchheight then
				leaves[#leaves+1] = sub1
			else
				branches[#branches+1] = sub1
			end

			if sub2:width() < minbranchwidth and sub2:height() < minbranchheight then
				leaves[#leaves+1] = sub2
			else
				branches[#branches+1] = sub2
			end
		end
	end

	local result = {}

	for _, bbox in ipairs(branches) do
		result[#result+1] = bbox:shrink(limits.margin * 0.5)
	end

	for _, bbox in ipairs(leaves) do
		result[#result+1] = bbox:shrink(limits.margin * 0.5)
	end

	return result
end

function layoutgen.splat( bbox, limits )
	local result = {}

	local minwidth = limits.minwidth + limits.margin * 1.5
	local minheight = limits.minheight + limits.margin * 1.5
	local maxwidth = limits.maxwidth or math.floor(bbox:width() * 0.5)
	local maxheight = limits.maxheight or math.floor(bbox:height() * 0.5)

	-- print('pre', minwidth, minheight, maxwidth, maxheight)

	local attempts = 0
	local maxattempts = 1000

	while #result < limits.maxboxes and attempts < maxattempts do
		local width = minwidth + math.random(0, maxwidth - minwidth)
		local height = minheight + math.random(0, maxheight - minheight)

		assert(width >= minwidth)
		assert(height >= minheight)

		local x = math.random(bbox.xmin, bbox.xmax - width)
		local y = math.random(bbox.ymin, bbox.ymax - height)

		local aabb = AABB.new {
			xmin = x,
			ymin = y,
			xmax = x + width,
			ymax = y + height,
		}

		assert(width == aabb:width())
		assert(height == aabb:height())

		local accepted = true

		for _, other in ipairs(result) do
			if aabb:intersects(other) then
				accepted = false

				break
			end
		end

		if accepted then
			result[#result+1] = aabb
		end

		attempts = attempts + 1
	end

	for index, bbox in ipairs(result) do
		-- print('shrink', bbox.xmin, bbox.ymin, bbox.xmax, bbox.ymax, bbox:width(), bbox:height())
		result[index] = bbox:shrink(limits.margin * 0.75)
	end

	return result
end








