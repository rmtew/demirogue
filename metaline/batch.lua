batch = {}

-- oob = out of bounds
local _oobpoint1 = { 10000, 10000 }
local _oobpoint2 = { 10001, 10001 }

-- The simplest but potentially most overdraw intensive batcher.
function batch.simple( w, h, point1s, point2s, numlines, width )
	local batches = {}
	local pixels = 0
	local oobs = 0

	for i = 1, #point1s, numlines do
		local p1s = {}
		local p2s = {}
		local xmin, xmax = 100000, 0
		local ymin, ymax = 100000, 0

		for j = 0, numlines - 1 do
			local p1 = point1s[i+j]
			local p2 = point2s[i+j]

			if p1 and p2 then
				p1s[j+1] = p1
				p2s[j+1] = p2

				-- print(p1[1], h - p1[2], p2[1], h - p2[2])

				xmin = math.min(xmin, p1[1], p2[1])
				xmax = math.max(xmax, p1[1], p2[1])
				ymin = math.min(ymin, h - p1[2], h - p2[2])
				ymax = math.max(ymax, h - p1[2], h - p2[2])
			else
				-- Make a line that won't be rendered.
				p1s[j+1] = _oobpoint1
				p2s[j+1] = _oobpoint2

				oobs = oobs + 1
			end
		end

		-- print('minmax', xmin, xmax, ymin, ymax)

		local x = math.max(xmin - width, 0)
		local y = math.max(ymin - width, 0)
		local pw = math.min((xmax - xmin) + 2 * width, w)
		local ph = math.min((ymax - ymin) + 2 * width, h)

		local aabb = { x, y, pw, ph }

		pixels = pixels + (pw * ph)

		local batch = {
			point1s = p1s,
			point2s = p2s,
			aabb = aabb,
			pixels = pw * ph
		}

		batches[#batches+1] = batch
	end

	return {
		batches = batches,
		pixels = pixels,
		oobs = oobs,
	}
end

-- BIH stand for Bounded Interval Hierarchy which is roughly what this batcher implements.
-- 1. Sort the lines either horizontally or vertically by (xmin or ymin)
-- 2. Evenly split the lines into two lists.
-- 3. Recursively sort the two lists by the opposite method used for the parent list.
-- 4. Once the lists are the size of a batch or smaller, emit a batch.
function batch.BIH( w, h, point1s, point2s, numlines, width )
	local batches = {}
	local pixels = 0
	local oobs = 0

	local function cmphorz( lhs, rhs )
		return math.min(lhs[1], lhs[3]) < math.min(rhs[1], rhs[3])
	end

	local function cmpvert( lhs, rhs )
		return math.min(lhs[2], lhs[4]) < math.min(rhs[2], rhs[4])
	end

	local function split( lines, horz )
		if #lines <= numlines then
			local point1s, point2s = {}, {}
			local xmin, xmax = 100000, 0
			local ymin, ymax = 100000, 0

			for i = 1, numlines do
				local line = lines[i]

				if line then
					local point1 = { line[1], line[2] }
					local point2 = { line[3], line[4] }

					point1s[i] = point1
					point2s[i] = point2

					xmin = math.min(xmin, point1[1], point2[1])
					xmax = math.max(xmax, point1[1], point2[1])
					ymin = math.min(ymin, h - point1[2], h - point2[2])
					ymax = math.max(ymax, h - point1[2], h - point2[2])
				else
					-- Make a line that won't be rendered.
					point1s[i] = _oobpoint1
					point2s[i] = _oobpoint2

					oobs = oobs + 1
				end
			end

			local x = math.max(xmin - width, 0)
			local y = math.max(ymin - width, 0)
			local pw = math.min((xmax - xmin) + 2 * width, w)
			local ph = math.min((ymax - ymin) + 2 * width, h)

			local aabb = { x, y, pw, ph }

			pixels = pixels + (pw * ph)

			local batch = {
				point1s = point1s,
				point2s = point2s,
				aabb = aabb,
				pixels = pw * ph
			}

			batches[#batches+1] = batch
		else
			table.sort(lines, (horz) and cmphorz or cmpvert)

			local mid = math.floor(0.5 + (#lines * 0.5))

			-- Lua doesn't have a table.sort(func, i, j) which is a great shame because
			-- we have to create copies of the arrays here :^(
			local lesslines, morelines = {}, {}

			for i = 1, mid do
				lesslines[i] = lines[i]
			end

			for i = mid + 1, #lines do
				morelines[i - mid] = lines[i]
			end

			split(lesslines, not horz)
			split(morelines, not horz)
		end
	end

	local lines = {}

	for i = 1, #point1s do
		local point1 = point1s[i]
		local point2 = point2s[i]

		lines[i] = { point1[1], point1[2], point2[1], point2[2] }
	end

	-- local horz = math.random() >= 0.5
	local horz = true

	split(lines, horz)

	return {
		batches = batches,
		pixels = pixels,
		oobs = oobs,
	}
end

-- Inspired by the R-Tree data structure. Should be the slowest batching method
-- but also causes the least overdraw.
-- 1. Sort the lines by bounding box area (smallest first).
-- 2. Pick the first/smallest area line.
-- 3. Now test against all remaining lines and select the one with the smallest mergeed bounding box.
-- 4. Repeat step 3 until you reach the batch size or run out of lines.
function batch.minarea( w, h, point1s, point2s, numlines, width )
	local batches = {}
	local pixels = 0
	local oobs = 0
	
	local function genaabb( line )
		local xmin = math.min(line[1], line[3])
		local xmax = math.max(line[1], line[3])
		local ymin = math.min(line[2], line[4])
		local ymax = math.max(line[2], line[4])

		return {
			xmin = xmin,
			ymin = ymin,
			xmax = xmax,
			ymax = ymax,
		}
	end

	local function aabbarea( aabb )
		return (aabb.xmax - aabb.xmin) * (aabb.ymax - aabb.ymin)
	end

	local function jointarea( aabb1, aabb2 )
		local xmin = math.min(aabb1.xmin, aabb2.xmin)
		local xmax = math.max(aabb1.xmax, aabb2.xmax)
		local ymin = math.min(aabb1.ymin, aabb2.ymin)
		local ymax = math.max(aabb1.ymax, aabb2.ymax)

		return (xmax - xmin) * (ymax - ymin)
	end

	local function mergeaabb( aabb1, aabb2 )
		local xmin = math.min(aabb1.xmin, aabb2.xmin)
		local xmax = math.max(aabb1.xmax, aabb2.xmax)
		local ymin = math.min(aabb1.ymin, aabb2.ymin)
		local ymax = math.max(aabb1.ymax, aabb2.ymax)

		return {
			xmin = xmin,
			ymin = ymin,
			xmax = xmax,
			ymax = ymax,
		}
	end

	local lines = {}

	for i = 1, #point1s do
		local point1 = point1s[i]
		local point2 = point2s[i]

		local line = { point1[1], point1[2], point2[1], point2[2], aabb = nil }
		line.aabb = genaabb(line)

		lines[i] = line
	end

	-- This means we always pick the smallest area line to start a bundle with.
	table.sort(lines,
		function ( lhs, rhs )
			return aabbarea(lhs.aabb) < aabbarea(rhs.aabb)
		end)

	-- I'm using pages to minimise the cost of the table.remove() calls to follow.
	-- It's a cheap and cheerful priority queue. Thee's no point using a heap or other
	-- tree based structure because we scan the entire list anyway.

	local pagesize = math.ceil(math.sqrt(#lines))
	local pages = {}

	for i = 0, #lines-1, pagesize do
		local page = {}

		for j = 1, pagesize do
			page[j] = lines[i + j]
		end

		pages[#pages+1] = page
	end

	local count = #lines

	while count > 0 do
		local bundle = { pages[1][1] }
		local aabb = bundle[1].aabb

		-- This trick is a *lot* faster than a table.remove().
		-- lines[1] = lines[#lines]
		-- lines[#lines] = nil
		table.remove(pages[1], 1)

		if #pages[1] == 0 then
			table.remove(pages, 1)
		end

		count = count - 1

		while #bundle < numlines and count > 0 do
			local minarea = math.huge
			local pageindex = nil
			local lineindex = nil

			for i, page in ipairs(pages) do
				for j, line in ipairs(page) do
					local area = jointarea(aabb, line.aabb)

					if area < minarea then
						minarea = area
						pageindex = i
						lineindex = j
					end
				end
			end

			local line = pages[pageindex][lineindex]
			bundle[#bundle+1] = line
			aabb = mergeaabb(aabb, line.aabb)

			-- lines[lineindex] = lines[#lines]
			-- lines[#lines] = nil
			table.remove(pages[pageindex], lineindex)

			if #pages[pageindex] == 0 then
				table.remove(pages, pageindex)
			end

			count = count - 1
		end

		-- turn the bundle into a batch
		local point1s = {}
		local point2s = {}
		local xmin, xmax = 100000, 0
		local ymin, ymax = 100000, 0

		for i = 1, numlines do
			local line = bundle[i]

			if line then
				local point1 = { line[1], line[2] }
				local point2 = { line[3], line[4] }

				point1s[i] = point1
				point2s[i] = point2

				xmin = math.min(xmin, point1[1], point2[1])
				xmax = math.max(xmax, point1[1], point2[1])
				ymin = math.min(ymin, h - point1[2], h - point2[2])
				ymax = math.max(ymax, h - point1[2], h - point2[2])
			else
				-- Make a line that won't be rendered.
				point1s[i] = _oobpoint1
				point2s[i] = _oobpoint2

				oobs = oobs + 1
			end
		end

		local x = math.max(xmin - width, 0)
		local y = math.max(ymin - width, 0)
		local pw = math.min((xmax - xmin) + 2 * width, w)
		local ph = math.min((ymax - ymin) + 2 * width, h)

		local aabb = { x, y, pw, ph }

		pixels = pixels + (pw * ph)

		local batch = {
			point1s = point1s,
			point2s = point2s,
			aabb = aabb,
			pixels = pw * ph
		}

		batches[#batches+1] = batch
	end

	return {
		batches = batches,
		pixels = pixels,
		oobs = oobs,
	}
end