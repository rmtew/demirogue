require 'Vector'

geometry = {}

local function _isConcaveEdge( point1, point2, point3 )
	local v1to3 = Vector.to(point1, point3)
	local v1to2 = Vector.to(point1, point2)

	return Vector.dot(v1to3:perp(), v1to2) > 0
end

-- Graham's scan, produces clockwise sequence of points.
-- NOTE: sorts the points so make a copy if the order matters.
-- NOTE: does no degeneracy testing.
function geometry.convexHull( points )
	-- Hulls don't make sense for points or lines.
	assert(#points > 2)

	table.sort(points,
		function ( lhs, rhs )
			if lhs[1] == rhs[1] then
				return lhs[2] < rhs[2]
			else
				return lhs[1] < rhs[1]
			end
		end)

	if #points == 3 then
		-- Ensure clockwise ordering.
		if points[2][2] < points[3][2] then
			points[2], points[3] = points[3], points[2]
		end

		return points
	end

	-- Create upper hull.
	local upper = { points[1], points[2] }
	for index= 3, #points do
		upper[#upper+1] = points[index]
		while #upper > 2 and not _isConcaveEdge(upper[#upper-2], upper[#upper-1], upper[#upper]) do
			table.remove(upper, #upper-1)
		end
	end

	-- Create lower hull.
	local lower = { points[#points], points[#points-1] }
	for i = #points-2,1,-1 do
		lower[#lower+1] = points[i]
		while #lower > 2 and not _isConcaveEdge(lower[#lower-2], lower[#lower-1], lower[#lower]) do
			table.remove(lower, #lower-1)
		end
	end

	-- The hulls into one.
	local hull = upper

	for i = 2, #lower-1 do
		hull[#hull+1] = lower[i]
	end

	return hull
end

-- NOTE: counts a point on the edge of the hull as being inside.
function geometry.isPointInHull( point, hull )
	local x, y = point[1], point[2]

	for index = 1, #hull do
		local point1 = hull[index]
		local point2 = hull[(index < #hull) and index + 1 or 1]

		local x1, y1 = point1[1], point1[2]
		local x2, y2 = point2[1], point2[2]

		local r = (y-y1)*(x2-x1)-(x-x1)*(y2-y1)
		
		if r == 0 then
			return true
		end

		if r > 0 then
			return false
		end
	end

	return true
end

