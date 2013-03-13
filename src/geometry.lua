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

function geometry.convexHullSignedArea( hull )
	local result = 0

	for i = 1, #hull do
		local p1 = hull[i]
		local p2 = hull[(i < #hull) and i+1 or 1]
		result = result + ((p1[1] * p2[2]) - (p2[1] * p1[2]))
	end

	return 0.5 * result
end

function geometry.convexHullCentroid( hull )
	local signedArea = 0
	local cx = 0
	local cy = 0

	for i = 1, #hull do
		local p1 = hull[i]
		local p2 = hull[(i < #hull) and i+1 or 1]

		local a = (p1[1] * p2[2]) - (p2[1] * p1[2])
		signedArea = signedArea + a
		
		cx = cx + (p1[1] + p2[1]) * a
		cy = cy + (p1[2] + p2[2]) * a
	end
	
	signedArea = 0.5 * signedArea
	local factor = 1 / (6 * signedArea)

	return Vector.new { factor * cx, factor * cy }
end

function geometry.furthestPointFrom( centre, points )
	local furthestDistance = 0
	local furthestPoint = nil

	for _, point in ipairs(points) do
		local distance = Vector.toLength(centre, point)

		if distance > furthestDistance then
			furthestDistance = distance
			furthestPoint = point
		end
	end

	return furthestPoint, furthestDistance
end

function geometry.closestPointOnLine( lineA, lineB, point )
	local aToP = Vector.to(lineA, point)
	local aToB = Vector.to(lineA, lineB)
    local aToBSqrLen = Vector.dot(aToB, aToB)
    local proj = aToP:dot(aToB)
    local t = proj / aToBSqrLen;
    
    if t < 0 then
    	t = 0
    elseif t > 1 then
    	t = 1
    end

    return Vector.new {
    	lineA[1] + aToB[1] * t,
    	lineA[2] + aToB[2] * t,
	}
end

function geometry.lineLineIntersection( line11, line12, line21, line22 )
	local p0_x, p0_y = line11[1], line11[2]
	local p1_x, p1_y = line12[1], line12[2]
	local p2_x, p2_y = line21[1], line21[2]
	local p3_x, p3_y = line22[1], line22[2] 

    local s10_x = p1_x - p0_x
    local s10_y = p1_y - p0_y
    local s32_x = p3_x - p2_x
    local s32_y = p3_y - p2_y

    local denom = s10_x * s32_y - s32_x * s10_y
    if denom == 0 then
        return false
    end

    local s02_x = p0_x - p2_x
    local s02_y = p0_y - p2_y
    local s_numer = s10_x * s02_y - s10_y * s02_x
    if s_numer < 0 then
        return false
    end

    local t_numer = s32_x * s02_y - s32_y * s02_x
    if t_numer < 0 then
        return false
    end

    if s_numer > denom or t_numer > denom then
        return false
    end

    local t = t_numer / denom
    local x = p0_x + (t * s10_x)
    local y = p0_y + (t * s10_y)

    return true, Vector.new { x, y }
end
