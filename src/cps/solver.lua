--
-- cps/solver.lua
--
-- AC3 based Constraint Propagation Solver
--

-- domain:
-- - variable(name, save)             - needs the save func for narrow() in variable
-- - constraint(name, variables, params)

-- variable:
-- - value                 - common name used by unwind() on solver
-- - domain                
-- - size()                - used for prioritising variable instantiation order
-- - empty()               - used as a sanity check
-- - unique()              
-- - narrow(value)
-- - each(random?)         - enumerates potential values, used as lua iterator
-- - constrain(constraint) - should be called before any other methods.
-- - resolve()             - called on unique variables to get the user facing value.

-- solver:
-- - variables { name = variable }
-- - 

local function newframe( solver )
	local stack = solver.stack
	local frame = {}
	stack[#stack+1] = frame
end

local function save( solver, var )
	local stack = solver.stack
	local frame = stack[#stack]

	local size = #frame
	frame[size+1] = var
	frame[size+2] = var.value
end

local function unwind( solver )
	local stack = solver.stack
	local frame = stack[#stack]

	for i = 1, #frame, 2 do
		frame[i].value = frame[i+1]
	end

	stack[#stack] = nil
end

--[[

-- These versions were causing NYI LuaJIT aborts because of the use of the
-- pairs iterator in unwind().

local function save( solver, var )
	local stack = solver.stack
	local frame = stack[#stack]

	if frame[var] ~= nil then
		printf('overwrite %s', var.name)
	end
	
	frame[var] = var.value
end

local function unwind( solver )
	local stack = solver.stack
	local frame = stack[#stack]

	-- TODO: causing a NYI in LuaJIT becuase of pairs().
	for variable, value in pairs(frame) do
		variable.value = value
	end

	stack[#stack] = nil
end
--]]

local function solution( varsarray )
	local result = {}

	for i = 1, #varsarray do
		local variable = varsarray[i]
		assert(variable:unique(), '%s is not unique', name)

		result[variable.name] = variable:resolve()
	end

	return result
end

local function solve( solver, option )
	-- check that we have no empty variables and build the varsarray
	local varsarray  = {}

	for name, variable in pairs(solver.variables) do
		assertf(not variable:empty(), '%s is empty', name)
		varsarray[#varsarray+1] = variable
	end

	-- It is generally better to solve for 'smaller' variables first.
	table.sort(varsarray,
		function ( lhs, rhs )
			local lsize = lhs:size()
			local rsize = rhs:size()

			if lsize ~= rsize then
				return lsize < rsize
			else
				return lhs.name < rhs.name
			end
		end)

	local iterate = solver.random and 'random'

	local function aux( solver, index )
		if index > #varsarray then
			coroutine.yield(solution(varsarray))

			return
		end

		local variable = varsarray[index]

		-- If the variable is unique we just carry on.		
		if variable:unique() then
			aux(solver, index+1)
		else
			for _, value in variable:each(iterate) do
				newframe(solver)
				if variable:narrow(value) then
					aux(solver, index+1)
				end
				
				unwind(solver)
			end
			return
		end
	end

	aux(solver, 1)
end

--
-- params = {
--     domains = { [name]=<domain> }+,
--     variables = { [name]=<domain-name> }+,
--     constraints = {
--         op=<name>,
--         variables={<variable-name>}+,
--         args={...}*
-- }
--
local function solver( params )
	local dump = params.dump == true
	local domains = params.domains

	local result = {
		variables = {},
		stack = {},
		random = params.random == true,
	}

	local variables = result.variables
	local saver = function ( var ) save(result, var) end
	
	for varname, domainname in pairs(params.variables) do
		local domain = domains[domainname]
		local variable = domain:variable(varname, saver)

		variables[varname] = variable
	end

	for _, def in ipairs(params.constraints) do
		local formals = {}
		local used = {}
		local domain = nil

		for _, varname in ipairs(def.variables) do
			assert(not used[varname])
			used[varname] = true

			local variable = variables[varname]

			assert(domain == nil or domain == variable.domain)
			domain = variable.domain
			assert(variable)
			
			formals[#formals+1] = variable
		end

		local constraint = domain:constraint(def.op, formals, def.args)
		for _, variable in ipairs(formals) do
			variable:constrain(constraint)
		end
	end

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

return solver
