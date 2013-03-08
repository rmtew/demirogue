function assertf( cond, ... )
	if not cond then
		error(string.format(...), 2)
	end
end


function math.round( value )
	return math.floor(0.5 + value)
end

function math.sign( value )
	if value < 0 then
		return -1
	else
		return 1
	end
end

function math.logb( x, base )
	return math.log(x) / math.log(base)
end

function table.keys( tbl )
	local result = {}

	for k, _ in pairs(tbl) do
		result[#result+1] = k
	end

	return result
end

-- Really just a shallow copy.
function table.copy( tbl )
	local result = {}

	for k, v in pairs(tbl) do
		result[k] = v
	end

	return result
end

function table.count( tbl )
	local result = 0

	for _ in pairs(tbl) do
		result = result + 1
	end

	return result
end

function table.random( tbl )
	local count = table.count(tbl)

	local index = math.random(1, count)
	local k = nil

	for i = 1, index do
		k = next(tbl, k)
	end

	return k, tbl[k]
end

function table.shuffle( tbl )
	for i = 1, #tbl-1 do
		local index = math.random(i, #tbl)
		tbl[i], tbl[index] = tbl[index], tbl[i]
	end
end

function table.collect( tbl, func )
	local result = {}

	for k, v in pairs(tbl) do
		result[k] = func(v)
	end

	return result
end


function printf( ... )
	print(string.format(...))
end

function table.print( tbl, indent )
	indent = indent or 0
	for k, v in pairs(tbl) do
		printf('%s%s = %s', string.rep(' ', indent), tostring(k), tostring(v))

		if type(v) == 'table' then
			table.print(v, indent + 2)
		end
	end
end

function fopen( filename, mode )
	local f
	if love then
		f = love.filesystem.newFile(filename)
		assertf(f:open(mode), 'fopen failed with %s %s', filename, tostring(mode))
	else
		f = io.open(filename, mode)
	end

	return f
end

-------------------------------------------------------------------------------

local epsilon = 1 / 2^7

function lerpf( value, in0, in1, out0, out1 )
    -- This isn't just to avoid a divide by zero but also a catstrophic loss of precision.
	assertf(math.abs(in1 - in0) > epsilon, "lerp() - in bounds [%f..%f] are too close together", in0, in1)
	local normed = (value - in0) / (in1 - in0)
	local result = out0 + (normed * (out1 - out0))
	return result
end

-------------------------------------------------------------------------------

-- TODO: This is less efficient than an array of arrays so change it.
function newgrid( width, height, value )
	local data = {}

	for x = 1, width do
		local column = {}
		for y = 1, height do
			column[y] = value
		end
		data[x] = column
	end

	return {
		width = width,
		height = height,
		set = 
			function ( x, y, value )
				data[x][y] = value
			end,
		get =
			function ( x, y )
				return data[x][y]
			end,
		print =
			function ()
				for y = 1, height do
					local line = {}
					for x = 1, width do
						line[x] = (data[x][y]) and 'x' or '.'
					end
					print(table.concat(line))
				end
			end,
	}
end

-------------------------------------------------------------------------------

Dampener = {}
Dampener.__index = Dampener

function Dampener.newf( value, target, bias )
	local result = {
		value = value,
		target = target,
		bias = bias,
	}

	setmetatable(result, Dampener)

	return result
end

function Dampener.newv( value, target, bias )
	local result = {
		value = { value[1], value[2] },
		target = { target[1], target[2] },
		bias = bias,
	}

	setmetatable(result, Dampener)

	return result
end

function Dampener:updatef( target )
	target = target or self.target

	self.value = self.value + self.bias * (target - self.value)

	return self.value
end

function Dampener:updatev( target )
	target = target or self.target

	local vtot = Vector.to(self.value, target)
	Vector.scale(vtot, self.bias)

	self.value[1] = self.value[1] + vtot[1]
	self.value[2] = self.value[2] + vtot[2]

	return self.value
end

-------------------------------------------------------------------------------

local _literals = {
	boolean =
		function ( value )
			if value then
				return 'true'
			else
				return 'false'
			end
		end,
	number =
		function ( value )
			if math.floor(value) == value then
				return string.format("%d", value)
			else
				return string.format("%.4f", value)
			end
		end,
	string =
		function ( value )
			return string.format("%q", value)
		end
}

function table.compile( tbl, option )
	local parts = { 'return ' }
	local pads = { [0] = '', '  ', '    ' }

	local next = next
	local string_rep = string.rep
	local type = type
	local _literals = _literals

	local function aux( tbl, indent )
		if next(tbl) == nil then
			parts[#parts+1] = '{}'
			return
		end

		parts[#parts+1] = '{\n'

		local padding = pads[indent]

		if not padding then
			padding = string_rep(' ', indent)
			pads[indent] = padding
		end

		local size = #tbl

		-- First off let's do the array part.
		for index = 1, size do
			local v = tbl[index]

			parts[#parts+1] = padding

			local vt = type(v)

			if vt ~= 'table' then
				parts[#parts+1] = _literals[vt](v)
			else
				aux(v, indent + 2)
			end

			parts[#parts+1] = ',\n'
		end

		-- Now non-array parts. This uses secret knowledge of how lua works, the
		-- next() function will iterate over array parts first so we can skip them.
		local k = next(tbl, (size ~= 0) and size or nil)

		while k ~= nil do
			parts[#parts+1] = padding
			parts[#parts+1] = '['

			local kt = type(k)

			if kt ~= 'table' then
				parts[#parts+1] = _literals[kt](k)
			else
				aux(k, indent + 2)
			end

			parts[#parts+1] = '] = '

			local v = tbl[k]
			local vt = type(v)

			if vt ~= 'table' then
				parts[#parts+1] = _literals[vt](v)
			else
				aux(v, indent + 2)
			end

			parts[#parts+1] = ',\n'

			k = next(tbl, k)
		end

		-- Closing braces are dedented.
		indent = indent - 2
		padding = pads[indent]

		if not padding then
			padding = string_rep(' ', indent)
			pads[indent] = padding
		end

		if padding ~= '' then
			parts[#parts+1] = padding
		end
		parts[#parts+1] = '}'
	end

	aux(tbl, 2)

	local result = table.concat(parts)

	return result
end
