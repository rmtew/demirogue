
function assertf( cond, ... )
	if not cond then
		error(string.format(...), 2)
	end
end


function math.round( value )
	return math.floor(0.5 + value)
end

function table.keys( tbl )
	local result = {}

	for k, _ in pairs(tbl) do
		result[#result+1] = k
	end

	return result
end

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

