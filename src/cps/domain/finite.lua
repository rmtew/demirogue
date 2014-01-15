--
-- cps/domain/finite.lua
--

local bit = require 'bit'

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

local Variable = {}
Variable.__index = Variable

function Variable:size()
	return self.domain.size
end

function Variable:empty()
	return self.value == 0
end

function Variable:unique()
	local value = self.value
	return value ~= 0 and bit.band(value, value-1) == 0
end

function Variable:narrow( value, depth )
	local newvalue = bit.band(value, self.value)

	if newvalue == 0 then
		return false
	end

	if self.value ~= newvalue then
		self:save()
		self.value = newvalue

		local constraints = self.constraints
		for index = 1, #constraints do
			if not constraints[index](self, depth) then
				return false
			end
		end
	end

	return true
end

function Variable:each( order )
	local values = {}
	local value = self.value
	local array = self.domain.array

	for i = 1, #array do
		local candidate = array[i]

		-- Only use values that haven't been ruled out.
		if bit.band(value, candidate) ~= 0 then
			values[#values+1] = candidate
		end
	end

	if order == 'random' then
		--table.shuffle(values)
	end

	return ipairs(values)
end

function Variable:constrain( constraint )
	local constraints = self.constraints
	constraints[#constraints+1] = constraint
end

function Variable:resolve()
	assert(self:unique())
	return self.domain:resolve(self.value)
end


local Domain = {}
Domain.__index = Domain

function Domain:variable( name, save )
	local result = {
		domain = self,
		name = name,
		value = self.default,
		constraints = {},
		save = save,
	}

	setmetatable(result, Variable)

	return result
end

function Domain:resolve( int )
	return self.intToValue[int]
end

-- constraints

local function neq( variables, args )
	assert(#variables == 2)
	assert(args == nil)

	local var1, var2 = variables[1], variables[2]

	return
		function ( var, depth )
			assert(var == var1 or var == var2)
			local other = (var == var1) and var2 or var1

			if var:unique() then
				local newvalue = bit.band(other.value, bit.bnot(var.value))
				return other:narrow(newvalue, depth+1)
			end

			return true
		end
end

local function distinct( variables, args )
	assert(#variables >= 2)
	assert(args == nil)

	local varset = {}
	for _, variable in pairs(variables) do
		varset[variable] = true
	end

	return
		function ( var, depth )
			assert(varset[var])

			if var:unique() then
				local mask = bit.bnot(var.value)
				for i = 1, #variables do
					local other = variables[i]
					if var ~= other then
						local newvalue = bit.band(other.value, mask)
						if not other:narrow(newvalue, depth+1) then
							return false
						end
					end
				end
			end

			return true
		end
end

local function eq( variables, args )
	assert(#variables == 2)
	assert(args == nil)

	local var1, var2 = vars[1], vars[2]

	return
		function ( var, depth )
			assert(var == var1 or var == var2)
			local other = (var == var1) and var2 or var1

			if var:unique() then
				return other:narrow(var.value, depth+1)
			end

			return true
		end
end

local function cardinality( variables, args )
	assert(#variables > 0)
	local domain = variables[1].domain
	assert(args.value)
	local value = domain.valueToInt[args.value]
	assert(value)

	local min = args.min or 0
	local max = args.max or math.huge

	assert(math.floor(min) == min and min == min and math.abs(min) ~= math.huge)
	assert(math.floor(max) == max and max == max and math.abs(max) ~= math.huge)
	assert(0 <= min)
	assert(min <= max)
	assert(min <= #variables)

	local varset = {}
	for i = 1, #variables do
		varset[variables[i]] = true
	end

	return
		function ( var, depth )
			assert(varset[var] ~= nil)

			local possible = {}
			local definite = {}
			local numdefinite = 0

			for i = 1, #variables do
				local variable = variables[i]

				if bit.band(variable.value, value) ~= 0 then
					possible[#possible+1] = variable
					
					local unique = variable:unique()
					definite[#definite+1] = unique
					numdefinite = numdefinite + (unique and 1 or 0)
				end
			end

			if #possible < min or numdefinite > max then
				return false
			end

			-- We have enough possibles, but only just, so try and make
			-- them definite to be sure.
			if #possible == min then
				for i = 1, #possible do
					local result = possible[i]:narrow(value, depth+1)

					if not result then
						return false
					end
				end

				return true
			end

			-- We've got the maximum number of definites so make the
			-- possibles that are not also definite into impossibles.
			if numdefinite == max then
				local mask = bit.bnot(value)
				for i =1, #possible do
					local variable = possible[i]
					if not definite[i] then
						local newvalue = bit.band(variable.value, mask)
						local result = variable:narrow(newvalue, depth+1)

						if not result then
							return false
						end
					end
				end
			end

			return true
		end
end

local constraints = {
	neq = neq,
	eq = eq,
	['~='] = neq,
	['=='] = eq,
	distinct = distinct,
	cardinality = cardinality,
}

function Domain:constraint( name, variables, args )
	assert(constraints[name])
	return constraints[name](variables, args)
end

function Domain:__tostring()
	return string.format('{ %s }', table.concat(values))
end

local function new( values )
	assert(#values > 0 and #values <= 32)

	local size = #values
	local valueToInt = {}
	local intToValue = {}
	local array = {}
	local default = 0
	for index, value in ipairs(values) do
		assert(valueToInt[value] == nil)
		local int  = bit.lshift(1, index-1)
		intToValue[int] = value
		valueToInt[value] = int 
		default = bit.bor(default, int)
		array[#array+1] = int
	end

	local result = {
		size = size,
		valueToInt = valueToInt,
		intToValue = intToValue,
		default = default,
		array = array,
	}

	setmetatable(result, Domain)

	return result
end

return new
