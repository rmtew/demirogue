math.randomseed(os.time())

assertf = function ( cond, ... ) if not cond then error(string.format(...), 2) end end
printf = function ( ... ) print(string.format(...)) end
table.shuffle = function( tbl )
	for i = 1, #tbl-1 do
		local index = math.random(i, #tbl)
		tbl[i], tbl[index] = tbl[index], tbl[i]
	end
end

local solver = require 'solver'
local finite = require 'domain/finite'

local problem = solver {
	domains = {
		bit = finite { '0', '1' }
	},
	variables = {
		a = 'bit',
		b = 'bit',
		c = 'bit',
		d = 'bit',
	},
	constraints = {},
	random = true,
}

function toline( tbl )
	local kvs = {}

	for k, v in pairs(tbl) do
		kvs[#kvs+1] = { k, v }
	end

	table.sort(kvs, function ( lhs, rhs ) return lhs[1] < rhs[1] end)

	local parts = {}
	for i, v in ipairs(kvs) do
		parts[#parts+1] = string.format('%s=%s', v[1], v[2])
	end

	return string.format('{%s}', table.concat(parts, ","))
end

local count = 0
for solution in problem do
	count = count + 1
	printf('#%d: %s', count, toline(solution))
end
print()

local problem = solver {
	domains = {
		bit = finite { '0', '1' }
	},
	variables = {
		a = 'bit',
		b = 'bit',
		c = 'bit',
		d = 'bit',
	},
	constraints = {
		{ op = '~=', variables = { 'a', 'b' } }
	}
}

local count = 0
for solution in problem do
	count = count + 1
	printf('#%d: %s', count, toline(solution))
end
print()

local problem = solver {
	domains = {
		bit = finite { '0', '1' }
	},
	variables = {
		a = 'bit',
		b = 'bit',
		c = 'bit',
		d = 'bit',
		e = 'bit',
		f = 'bit',
		g = 'bit',
		h = 'bit',
		i = 'bit',
		j = 'bit',
		k = 'bit',
		l = 'bit',
		m = 'bit',
		n = 'bit',
		o = 'bit',
		p = 'bit',
	},
	constraints = {
		{
			op = 'cardinality',
			variables = { 'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p' },
			args = {
				value = '1',
				min = 1,
				max = 1,
			}
		}
	}
}

function vtoline( tbl )
	local kvs = {}

	for k, v in pairs(tbl) do
		kvs[#kvs+1] = { k, v }
	end

	table.sort(kvs, function ( lhs, rhs ) return lhs[1] < rhs[1] end)

	local parts = {}
	for i, v in ipairs(kvs) do
		parts[#parts+1] = string.format('%s', v[2])
	end

	return string.format('{%s}', table.concat(parts, ","))
end

local count = 0
for solution in problem do
	count = count + 1
	printf('#%d: %s', count, vtoline(solution))
end
print()

local domain = finite { 'q', '.' }
local variables = {}
local all = {}
local rows = { {}, {}, {}, {}, {}, {}, {}, {} }
local columns = { {}, {}, {}, {}, {}, {}, {}, {} }

for x = 1, 8 do
	for y = 1, 8 do
		local variable = string.format('%d-%d', x, y)
		variables[variable] = 'domain'
		all[#all+1] = variable
		rows[x][y] = variable
		columns[y][x] = variable
	end
end

local constraints = {
	{ op='cardinality', variables=all, args = { value='q', min=8, max=8 } }
}
for _, row in ipairs(rows) do
	local constraint = { op='cardinality', variables = row, args = { value = 'q', min=0, max=1 } }
	constraints[#constraints+1] = constraint
end

for _, column in ipairs(columns) do
	local constraint = { op='cardinality', variables = column, args = { value = 'q', min=0, max=1 } }
	constraints[#constraints+1] = constraint
end

local diag1 = {
	{ '1-1' },
	{ '1-2', '2-1' },
	{ '1-3', '2-2', '3-1' },
	{ '1-4', '2-3', '3-2', '4-1' },
	{ '1-5', '2-4', '3-3', '4-2', '5-1' },
	{ '1-6', '2-5', '3-4', '4-3', '5-2', '6-1' },
	{ '1-7', '2-6', '3-5', '4-4', '5-3', '6-2', '7-1' },
	{ '1-8', '2-7', '3-6', '4-5', '5-4', '6-3', '7-2', '8-1' },
	{ '2-8', '3-7', '4-6', '5-5', '6-4', '7-3', '8-2' },
	{ '3-8', '4-7', '5-6', '6-5', '7-4', '8-3' },
	{ '4-8', '5-7', '6-6', '7-5', '8-4' },
	{ '5-8', '6-7', '7-6', '8-5' },
	{ '6-8', '7-7', '8-6' },
	{ '7-8', '8-7' },
	{ '8-8' },
}

local diag2 = {}

for i, line1 in ipairs(diag1) do
	local line2 = {}
	for j, coord in ipairs(line1) do
		local x, y = coord:match('(%d)%-(%d)')
		assert(x)
		assert(y)
		line2[j] = string.format('%d-%d', 8 - x + 1, y)
	end

	diag2[i] = line2
end

function board( vars )
	local set = {}
	for _, v in ipairs(vars) do
		set[v] = true
	end

	local lines = { {}, {}, {}, {}, {}, {}, {}, {} }

	for y = 1, 8 do
		for x = 1, 8 do
			local var = string.format('%d-%d', x, y)
			lines[y][x] = set[var] and '#' or '.'
		end
	end

	for _, line in ipairs(lines) do
		print(table.concat(line, ' '))
	end
	print()
end

for _, diag in ipairs(diag1) do
	local constraint = { op='cardinality', variables = diag, args = { value = 'q', min=0, max=1 } }
	constraints[#constraints+1] = constraint
	-- board(diag)
end

for _, diag in ipairs(diag2) do
	local constraint = { op='cardinality', variables = diag, args = { value = 'q', min=0, max=1 } }
	constraints[#constraints+1] = constraint
	-- board(diag)
end

local problem = solver {
	domains = { domain = domain },
	variables = variables,
	constraints = constraints,
}

local count = 0
local solutions = {}
local start = os.clock()
for solution in problem do
	count = count + 1
	solutions[#solutions+1] = solution
end
local finish = os.clock()
printf('%d %ss', #solutions, finish-start)

for index, solution in ipairs(solutions) do
	printf('#%d:', index)

	local lines = { {}, {}, {}, {}, {}, {}, {}, {} }

	for y = 1, 8 do
		for x = 1, 8 do
			local var = string.format('%d-%d', x, y)
			lines[y][x] = solution[var]
		end
	end

	for _, line in ipairs(lines) do
		print(table.concat(line, ' '))
	end
end

printf('%d %ss', #solutions, finish-start)

local function eq( lhs, rhs )
	for k, v in pairs(lhs) do
		if v ~= rhs[k] then
			return false
		end
	end

	return true
end

for i = 1, #solutions-1 do
	local a = solutions[i]
	for j = i+1, #solutions do
		local b = solutions[j]
		if eq(a, b) then
			printf('%d == %d', i, j)
		end
	end
end
print()


local problem = solver {
	domains = {
		domain = finite { '1', '2', '3', '4', '5', '6', '7', '8' }
	},
	variables = {
		a = 'domain',
		b = 'domain',
		c = 'domain',
		d = 'domain',
		e = 'domain',
		f = 'domain',
		g = 'domain',
		h = 'domain',
	},
	constraints = {
		{ op='distinct', variables = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' } }
	},
}

local count = 0
local start = os.clock()
for solution in problem do
	count = count + 1
end
local finish = os.clock()
printf('%d %ss', count, finish-start)
assertf(count == 40320, 'expected 8! = 40,320 but got %d', count)
print()
