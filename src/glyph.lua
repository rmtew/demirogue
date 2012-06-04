glyph = {}
glyph.__index = glyph

local function _copy( tbl )
	local result = {}

	for i, v in ipairs(tbl) do
		result[i] = v
	end

	return result
end

function glyph.new( params )
	local result = {
		points = {},
		lines = {}
	}

	setmetatable(result, glyph)

	if params then
		local points = result.points

		for index = 1, #points, 2 do
			result:addPoint(vector.new { x = points[index], y = points[index+1] })
		end

		local lines = result.lines
		for _, line in ipairs(params.lines) do
			lines[#lines+1] = _copy(line)
		end
	end

	return result
end

function glyph:addPoint( point, index )
	local points = self.points

	index = index or #points+1
	assert(1 >= index or index <= #points+1)
	
	points[index] = vector.new(point)

	return index
end

function glyph:removePoint( index )
	local points = self.points
	assert(1 >= index or index <= #points+1)

	table.remove(points, index)
end

function glyph:addLine( points, index )
	local lines = self.lines

	index = index or #lines+1
	assert(1 >= index or index <= #lines+1)

	local pts = {}

	for i, point in ipairs(points) do
		pts[#pts+1] = point[1]
		pts[#pts+1] = point[2]
	end

	lines[index] = pts

	return index
end

function glyph:removeLine( index )
	local lines = self.lines
	assert(1 >= index or index <= #lines+1)

	table.remove(lines, index)
end

function glyph:draw( fg, bg, fgwidth, bgwidth )
	love.graphics.setLineStyle('rough')
	love.graphics.setColor(bg.r, bg.g, bg.b, bg.a)
	love.graphics.setPointSize(bgwidth)
	love.graphics.setLineWidth(bgwidth)

	for _, point in ipairs(self.points) do
		love.graphics.point(point[1], point[2])
	end

	for _, line in ipairs(self.lines) do
		love.graphics.line(line)
	end

	love.graphics.setColor(fg.r, fg.g, fg.b, fg.a)
	love.graphics.setPointSize(fgwidth)
	love.graphics.setLineWidth(fgwidth)

	for _, point in ipairs(self.points) do
		love.graphics.point(point[1], point[2])
	end

	for _, line in ipairs(self.lines) do
		love.graphics.line(line)
	end
end

local function printf( ... )
	print(string.format(...))
end

function glyph:dump()
	printf('{')
	printf('  points = {')

	for _, point in ipairs(self.points) do
		printf('    %d, %d,', point[1], point[2])
	end

	printf('  },')
	printf('  lines = {')

	for _, line in ipairs(self.lines) do
		local parts = { '    { ' }

		for i = 1, #line, 2 do
			parts[#parts+1] = line[i]
			parts[#parts+1] = line[i+1]
		end

		parts[#parts+1] = ' }'

		print(table.concat(parts, ', '))
	end

	printf('  },')
	printf('}')
end