KDTree = {}
KDTree.__index = KDTree

function KDTree.new( points )
	local function cmphorz( lhs, rhs )
		return lhs[1] < rhs[1]
	end

	local function cmpvert( lhs, rhs )
		return lhs[2] < rhs[2]
	end

	local function split( points, horz )
		if #points <= 1 then
			return points[1]
		end

		table.sort(points, (horz) and cmphorz or cmpvert)
	
		local mid = math.round(#points * 0.5)

		-- Lua doesn't have a table.sort(func, i, j) which is a great shame because
		-- we have to create copies of the arrays here :^(
		local less, more = {}, {}

		for i = 1, mid do
			less[i] = points[i]
		end

		for i = mid + 1, #points do
			more[i - mid] = points[i]
		end

		return {
			horz = horz,
			axis = points[mid][horz and 1 or 2],
			split(less, not horz),
			split(more, not horz),
		}
	end

	-- local horz = math.random() >= 0.5
	local horz = true

	local result =  split(points, horz)

	setmetatable(result, KDTree)

	return result
end
