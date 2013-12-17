--
-- Simple Finite Domain, Constraint Propagation Solver
--
-- Inspired by 'Fast Procedural Level Population with Playability Constraints'
-- by Ian Horswill and Leif Foged.
--
-- paper: http://www.aaai.org/ocs/index.php/AIIDE/AIIDE12/paper/view/5466/5691
-- code:  http://code.google.com/p/constraint-thingy/
--
-- I haven't implemented any of the more advanced parts of the paper like
-- interval domains or any of the DAG based pathing stuff.
--
-- It's not very efficient as it uses tables (Lua's built in hash map) for
-- representing domains instead of bit arrays but it is simple.
--

--
-- Domains
--
-- The solve(), narrow() and solution() functions require the following
-- interface from domains:
--
-- - size(domain)
--     This is used to order the variables so it doesn't have to be precise.
--     The only possible exceptions are if the domain has 0 or 1 elements.
-- - intersection(domain1, domain2)
--     Used in narrow() to allow the set argument to be more flexible.
-- - is_empty(domain), size(domain) == 0
--     If any variable is initially empty or a narrow() attempt yields an empty
--     intersection it is a problem.
-- - is_singleton(domain), size(domain) == 1
--     Means the associated variable is assigned.
-- - value(domain), where is_singleton(domain)
--     Need to be able to extract the unique value of a singleton domain.
-- - is_equal(domain1, domain2)
--     Avoids uneeded work in narrow() and also the chance of infinite recursion.
-- - for value in values(domain)
--     This could either return the value or a singleton domain (in which case
--     the following function isn't needed). May need a variant that iterates
--     randomly so a client can get a single solution that they know is unique.
-- - create_singleton_domain(value)
--     Not needed if the value iterator return singleton domains instead of
--     values.



-- variable = {
--     name = <string>,
--     values = { [<value>] = true }*
-- }

-- constraint = function ( solver, variable )

-- solver = {
--     variables = { [variable] = true }+
--     varmap = { [<string>] = variable }+
--     constraints = { [variable] = { constraint }+ }+
--     stack = { { variables } }*
-- }

function printf( ... ) print(string.format(...)) end

function set( value )
	return { [value] = true }
end

function set_empty( set )
	return next(set) == nil
end

function set_singular( set )
	local k = next(set)

	return k ~= nil and next(set, k) == nil
end

function set_count( set )
	local result = 0

	for k, _ in pairs(set) do
		result = result + 1
	end

	return result
end

function set_copy( set )
	local result = {}

	for k, _ in pairs(set) do
		result[k] = true
	end

	return result
end

function set_intersection( set1, set2 )
	local result = {}

	for k, _ in pairs(set1) do
		if set2[k] then
			result[k] = true
		end
	end

	return result
end

function set_subtract( set1, set2 )
	local result = {}

	for k, _ in pairs(set1) do
		if not set2[k] then
			result[k] = true
		end
	end

	return result
end

function set_equal( set1, set2 )
	for k, _ in pairs(set1) do
		if not set2[k] then
			return false
		end
	end

	for k,_ in pairs(set2) do
		if not set1[k] then
			return false
		end
	end

	return true
end

function set_toarray( set )
	local result = {}

	for k, _ in pairs(set) do
		result[#result+1] = k
	end

	return result
end

function set_fromarray( array )
	local result = {}

	for _, v in ipairs(array) do
		result[v] = true
	end

	return result
end

function set_tostring( set )
	local parts = {}

	for k, _ in pairs(set) do
		parts[#parts+1] = k
	end

	return string.format("{%s}", table.concat(parts, ' '))
end

function print_stack( solver )
	for index, frame in ipairs(solver.stack) do
		printf('%d ->', index)

		for variable, values in pairs(frame) do
			printf('  %s = %s', variable.name, set_tostring(values))
		end
	end
end

function newframe( solver )
	local stack = solver.stack
	local frame = {}
	stack[#stack+1] = frame
end

function save( solver, var )
	local stack = solver.stack
	local frame = stack[#stack]
	
	frame[var] = var.values
end

function unwind( solver )
	local stack = solver.stack
	local frame = stack[#stack]

	for variable, values in pairs(frame) do
		variable.values = values
	end

	stack[#stack] = nil
end

function solution( solver )
	local result = {}

	for variable, _ in pairs(solver.variables) do
		assert(set_singular(variable.values))

		result[variable.name] = next(variable.values)
	end

	return result
end

function narrow( solver, var, set )
	-- printf('  narrow %s to %s', vartos(var), set_tostring(set))
	local newvalues = set_intersection(var.values, set)

	if set_empty(newvalues) then
		return false
	end

	if not set_equal(var.values, newvalues) then
		save(solver, var)

		var.values = newvalues

		local constraints = solver.constraints[var]

		-- printf('  propagate %s over %d constraints', vartos(var), set_count(constraints))

		for constraint, _ in pairs(constraints) do
			if not constraint(solver, var) then
				return false
			end
		end
	end

	return true
end

function solve( solver )
	local varsarray = set_toarray(solver.variables)

	-- We want to try and solve the 'smallest' variables first. This also
	-- allows a quick check for any empty variables.
	table.sort(varsarray,
		function ( lhs, rhs )
			return set_count(lhs.values) < set_count(rhs.values)
		end)

	-- If there's any empty variables we're buggered.
	if set_empty(varsarray[1].values) then
		error('empty')
	end

	local function aux( solver, index )
		if index > #varsarray then
			coroutine.yield(solution(solver))

			return
		end

		local variable = varsarray[index]

		-- If the variable is singular (i.e. has a value) we just carry on.		
		if set_singular(variable.values) then
			aux(solver, index+1)
		else
			-- local failed = true

			for value, _ in pairs(variable.values) do
				newframe(solver)

				-- printf(' try %s = %s', variable.name, value)

				local success = narrow(solver, variable, set(value))

				if success then
					-- failed = false
					-- print(debug.traceback())
					aux(solver, index+1)
				end
				
				unwind(solver)
			end

			-- if not failed then
				return
			-- else
				-- error('unsatisfiable')
			-- end
		end
	end

	aux(solver, 1)
end

function printTable( tbl )
	for k, v in pairs(tbl) do
		print(k, v)
	end
end

function environment( varnames, varmap )
	local result = {}

	local repeated = {}

	for _, varname in ipairs(varnames) do
		local variable = varmap[varname]
		assert(variable)
		assert(not repeated[variable], variable.name)
		result[#result+1] = variable
		repeated[variable] = true
	end

	return result
end

function vartos( var, values )
	values = values or var.values
	return string.format("%s=%s", var.name, set_tostring(values))
end

local numcfails = 0
local numfwfails = 0

local _constraints = {
	NotEqual =
		function ( vars )
			assert(#vars == 2)

			local var1, var2 = vars[1], vars[2]

			return
				function ( solver, var )
					assert(var == var1 or var == var2)
					local other = (var == var1) and var2 or var1

					if set_singular(var.values) then
						local newvalues = set_subtract(other.values, var.values)
						local oldvalues = other.values

						-- printf('  NotEqual %s %s => %s', vartos(var), vartos(other, oldvalues), set_tostring(newvalues))

						local result = narrow(solver, other, newvalues)

						-- printf('   %s', result and 'succeeded' or 'failed')

						return result
					end

					return true
				end
		end,
	Equal =
		function ( vars )
			assert(#vars == 2)

			local var1, var2 = vars[1], vars[2]

			return
				function ( solver, var )
					assert(var == var1 or var == var2)
					local other = (var == var1) and var2 or var1

					if set_singular(var.values) then
						local newvalues = set_copy(var.values)
						local oldvalues = other.values

						-- printf('  Equal %s %s => %s', vartos(var), vartos(other, oldvalues), set_tostring(newvalues))

						local result = narrow(solver, other, newvalues)

						-- printf('   %s', result and 'succeeded' or 'failed')

						return result
					end

					return true
				end
		end,
	Cardinality =
		function ( vars, params )
			local min = params.min
			local max = params.max
			local value = params.value

			assert(0 <= min)
			assert(min <= max)
			assert(value)
			assert(min <= #vars)

			local variables = set_fromarray(vars)

			return
				function ( solver, var )
					assert(variables[var])

					local possible = {}
					local definite = {}
					local numpossible = 0
					local numdefinite = 0

					for variable, _ in pairs(variables) do
						if variable.values[value] then
							possible[variable] = true
							numpossible = numpossible + 1

							if set_singular(variable.values) then
								definite[variable] = true
								numdefinite = numdefinite + 1
							end
						end
					end

					if numpossible < min or numdefinite > max then
						numcfails = numcfails + 1
						return false
					end

					-- We have enough possibles, but only just, so try and make
					-- them definite to be sure.
					if numpossible == min then
						for variable, _ in pairs(possible) do
							local result = narrow(solver, variable, set(value))

							if not result then
								numcfails = numcfails + 1
								return false
							end
						end

						return true
					end

					-- We've got the maximum number of definites so make the
					-- possibles that are not also definite into impossibles.
					if numdefinite == max then
						local valueset = set(value)

						for variable, _ in pairs(possible) do
							if not definite[variable] then
								local newvalues = set_subtract(variable.values, valueset)

								-- printf('  Cardinality %s => %s', vartos(variable), set_tostring(newvalues))

								local result = narrow(solver, variable, newvalues)

								if not result then
									numcfails = numcfails + 1
									return false
								end
							end
						end

						return true
					end

					return true
				end
		end,
	Sum =
		function ( vars, params )
			assert(#vars > 0)

			local total = params.total
			assert(total)

			return
				function ( solver, var )
					local count = 0

					-- print(#vars)

					for _, variable in ipairs(vars) do
						if not set_singular(variable.values) then
							return true
						else
							-- TODO: Need a 'get unique value' function.
							count = count + next(variable.values)
						end
					end

					-- printf('  Sum count:%d total:%d', count, total)

					return count == total
				end
		end,
	FourWayConnected =
		function ( vars, params )
			local height = params.height
			local width = params.width
			local passable = params.passable

			assert(#vars == width * height)

			-- Build up the 'neighbour' relation.
			local neighbours = {}

			local at = 
				function ( x, y )
					local result = x + (y-1)*width
					assert(1 <= result and result <= width * height)
					return result
				end

			for y = 1, height do
				for x = 1, width do
					local peers = {}
					
					-- North
					if y > 1 then
						peers[#peers+1] = vars[at(x, y-1)]
					end

					-- East
					if x < width then
						peers[#peers+1] = vars[at(x+1, y)]
					end

					-- South
					if y < height then
						peers[#peers+1] = vars[at(x, y+1)]
					end

					-- West
					if x > 1 then
						peers[#peers+1] = vars[at(x-1, y)]
					end

					neighbours[vars[at(x, y)]] = peers
				end
			end

			return
				function ( solver, var )
					for _, variable in ipairs(vars) do
						if not set_singular(variable.values) then
							return true
						end
					end

					-- First create a set of passable variables.
					local passables = {}
					local numpassables = 0

					for _, variable in ipairs(vars) do
						if passable[next(variable.values)] then
							passables[variable] = true
							numpassables = numpassables + 1
						end
					end

					if set_count(passables) == 0 then
						return true
					else
						local bfs = function( variable )
							local result = { [variable] = true }
							local frontier = { [variable] = true }
							local count = 1

							while next(frontier) do
								local newFrontier = {}

								for variable, _  in pairs(frontier) do
									for _, other in ipairs(neighbours[variable]) do
										if not result[other] and not frontier[other] and passables[other] then
											count = count + 1
											result[other] = true
											newFrontier[other] = true
										end
									end
								end

								frontier = newFrontier
							end

							return count
						end

						local count = bfs(next(passables))

						if count ~= numpassables then
							numfwfails = numfwfails + 1

							if numcfails % 1000 == 0 or numfwfails % 1000 == 0 then
								-- printf('#card:%d #fourw:%d', numcfails, numfwfails)
							end
						end

						return count == numpassables
					end
				end
		end,
}

-- tbl = {
--     vars = { [<string>] = { <string> }+ },
--     constraints = { { <string>, vars = { <string> }+ } }*
-- }


function newSolver( tbl )
	local dump = tbl.dump == true

	local vars = tbl.vars

	local variables = {}
	local varmap = {}

	for name, values in pairs(vars) do
		assert(#values >= 1)

		local variable = { name = name, values = set_fromarray(values) }
		variables[variable] = true
		varmap[name] = variable

		if dump then
			print(vartos(variable))
		end
	end

	local constraints = {}

	for variable, _ in pairs(variables) do
		constraints[variable] = {}
	end

	for index, v in ipairs(tbl.constraints) do
		local name = v[1]
		local vars = environment(v.vars, varmap)
		local params = v.params

		local constraint = _constraints[name](vars, params)

		for _, variable, _ in ipairs(vars) do
			if dump then
				printf('constraint #%d %s', index, variable.name)
			end

			constraints[variable][constraint] = true
		end
	end

	local result = {
		variables = variables,
		varmap = varmap,
		constraints = constraints,
		stack = {},
	}

	local coro = coroutine.create(function () solve(result) end)
	
	return
		function ()
			local status, result = coroutine.resume(coro)

			if status then
				return result
			else
				error(result)
				return nil
			end
		end
end

function solution_tostring( solution )
	local sorted = {}

	for varname, value in pairs(solution) do
		sorted[#sorted+1] = { varname, value }
	end

	table.sort(sorted,
		function ( lhs, rhs )
			return lhs[1] < rhs[1]
		end)

	local parts = {}

	for _, data in pairs(sorted) do
		parts[#parts+1] = string.format("%s=%s", data[1], data[2])
	end

	return string.format("{ %s }", table.concat(parts, ' '))
end

function enumerate( solver )
	local count = 0

	for solution in solver do
		count = count + 1
		printf('#%d %s', count, solution_tostring(solution))
	end

	printf('%d solutions', count)
	print()

	return count
end

function enumerate2( solver )
	local count = 0

	for solution in solver do
		count = count + 1

		if count % 1000 == 0 then
			printf('#%d %s', count, solution_tostring(solution))
		end
	end

	printf('%d solutions', count)
	print()
end

local solver = newSolver {
	vars = {
		a = { 'x', 'y', 'z' },
		b = { 'x', 'y', 'z' },
		c = { 'x', 'y', 'z' },
	},
	constraints = {},
}

enumerate(solver)

local solver = newSolver {
	dump = true,
	vars = {
		a = { 'x', 'y', 'z' },
		b = { 'x', 'y', 'z' },
		c = { 'x', 'y', 'z' },
	},
	constraints = {
		{ 'NotEqual', vars = { 'a', 'b' } },
		{ 'NotEqual', vars = { 'a', 'c' } },
		{ 'NotEqual', vars = { 'b', 'c' } },
	},
}

assert(enumerate(solver) == 6)

local solver = newSolver {
	vars = {
		a = { 'x', 'y', 'z' },
		b = { 'x', 'y', 'z' },
		c = { 'x', 'y', 'z' },
	},
	constraints = {
		{ 'Equal', vars = { 'a', 'b' } },
		{ 'Equal', vars = { 'a', 'c' } },
		{ 'Equal', vars = { 'b', 'c' } },
	},
}

assert(enumerate(solver) == 3)

function genNotEquals( varnames )
	local result = {}

	for i = 1, #varnames do
		for j = i+1, #varnames do
			result[#result+1] = { 'NotEqual', vars = { varnames[i], varnames[j] } }
		end
	end

	return result
end

local solver = newSolver {
	vars = {
		a = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		b = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		c = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		d = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		e = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		f = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		g = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		h = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		i = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		j = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		k = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
		l = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',  },
	},
	constraints = genNotEquals { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l' } ,
}

-- This should have 12! = 479,001,600 solutions.
-- enumerate2(solver)

local solver = newSolver {
	vars = {
		a = { '0', '1', },
		b = { '0', '1', },
		c = { '0', '1', },
		d = { '0', '1', },
	},
	constraints = {
		{ 'Cardinality', vars = { 'a', 'b', 'c', 'd' }, params = { min = 2, max = 3, value = '1' } },
	},
}

assert(enumerate(solver) == 10)

local solver = newSolver {
	vars = {
		a = { '0', '1', },
		b = { '0', '1', },
		c = { '0', '1', },
		d = { '0', '1', },
		e = { '0', '1', },
		f = { '0', '1', },
		g = { '0', '1', },
		h = { '0', '1', },
		i = { '0', '1', },
		j = { '0', '1', },
		k = { '0', '1', },
		l = { '0', '1', },
		m = { '0', '1', },
		n = { '0', '1', },
		o = { '0', '1', },
		r = { '0', '1', },
		s = { '0', '1', },
		t = { '0', '1', },
		u = { '0', '1', },
		v = { '0', '1', },
		w = { '0', '1', },
		x = { '0', '1', },
		y = { '0', '1', },
		z = { '0', '1', },
	},
	constraints = {
		{ 'Cardinality', vars = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' }, params = { min = 13, max = 13, value = '1' } },
	},
}

-- enumerate2(solver)

local solver = newSolver {
	vars = {
		a = { 0, 1, 2, 3, 4, 5, },
		b = { 0, 1, 2, 3, 4, 5, },
		c = { 0, 1, 2, 3, 4, 5, },
		d = { 0, 1, 2, 3, 4, 5, },
	},
	constraints = {
		{ 'Sum', vars = { 'a', 'b', 'c', 'd' }, params = { total = 2 } },
	},
}

enumerate(solver)

local solver = newSolver {
	vars = {
		a11 = { '#', '.' },
		a21 = { '#', '.' },
		a31 = { '#', '.' },
		a12 = { '#', '.' },
		a22 = { '#', '.' },
		a32 = { '#', '.' },
		a13 = { '#', '.' },
		a23 = { '#', '.' },
		a33 = { '#', '.' },
	},
	constraints = {
		{ 'FourWayConnected', vars = { 'a11', 'a21', 'a31', 'a12', 'a22', 'a32', 'a13', 'a23', 'a33' }, params = { width = 3, height = 3, passable = { ['.'] = true } } },
	},
}

-- enumerate3(solver)

function enumeratemap( width, height, minf, maxf )
	assert(width >= 3)
	assert(height >= 3)
	assert(0 <= minf and minf <= 1)
	assert(0 <= maxf and maxf <= 1)
	assert(minf <= maxf)

	local min = math.floor((width*height)*minf)
	local max = math.floor((width*height)*maxf)

	local vars = {}
	local varnames = {}
	local domain = { '#', '.' }
	local border = { '#' }
	local passable = { ['.'] = true }

	local entrances = {}
	local exits = {}

	for y = 1, height do
		for x = 1, width do
			local var = string.format("%d_%d", x, y)

			local bordered = (y == 1 or y == height)

			if bordered then
				vars[var] = border
			else
				vars[var] = domain
				varnames[#varnames+1] = var
			end

			if x == 1 and y > 1 and y < height then
				entrances[#entrances+1] = var
			end

			if x == width and y > 1 and y < height then
				exits[#exits+1] = var
			end
		end
	end

	local solver = newSolver {
		vars = vars,
		constraints = {
			{
				'FourWayConnected',
				vars = varnames,
				params = {
					width = width,
					height = height-2,
					passable = passable
				},
			},
			{
				'Cardinality',
				vars = varnames,
				params = {
					min = min,
					max = max,
					value = '.'
				}
			},
			{
				'Cardinality',
				vars = entrances,
				params = {
					min = 1,
					max = 1,
					value = '.'
				}
			},
			{
				'Cardinality',
				vars = exits,
				params = {
					min = 1,
					max = 1,
					value = '.'
				}
			},
		},		
	}

	local count = 0

	for solution in solver do
		count = count + 1

		--if count % 100 == 0 then

			printf('#%d', count)

			for y = 1, height do
				local line = {}
				for x = 1, width do
					local var = string.format("%d_%d", x, y)
					line[#line+1] = solution[var]
				end
				print(table.concat(line))
			end
			
			print()
		-- end
	end

	printf('%d solutions', count)
	print()

	return count
end

for i = 8, 8 do
	local min = 0.3
	local max = 0.4
	printf('enumeratemap(%d, %d, %f, %f)', i, i, min, max)
	enumeratemap(i, i, min, max)
	print()
end
