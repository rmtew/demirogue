--
-- themes.lua
--

themes = {
	db = {},
	sortedDB = {},
}

function themes.saveRuleset( theme, data )
	local code = table.compile(data)

	local ruleset = loadstring(code)
	assert(ruleset)

	theme.ruleset = ruleset

	local file = love.filesystem.newFile(theme.path)
	file:open('w')
	file:write(code)
	file:close()
end

local function _isName( value )
	return type(value) == 'string' and value:match('^(%a%w*)$') ~= nil
end

local function _isFinite( value )
	return type(value) == 'number' and value == value and math.abs(value) ~= math.huge
end

local function _isInt( value )
	return _isFinite(value) and math.floor(value) == value
end

local function _isNonNegInt( value )
	return _isInt(value) and value > 0
end

local function _isPosNum( value )
	return _isFinite(value) and value > 0
end

-- Like assertf() but makes the error happen a level further up the stack.
local function checkf( cond, ... )
	if not cond then
		error(string.format(...), 3)
	end
end

local _emptyRuleset = [[
return {
    {
	    leftGraph = {
	        vertices = {},
	        edges = {},
	    },
	    rightGraph = {
	        vertices = {},
	        edges = {},
	    },
	    map = {},
	},
}
]]

local function Theme( params )
	local template = params.template

	if template then
		local clone = table.copy(template)
		clone.template = nil

		for k, v in pairs(params) do
			clone[k] = v
		end

		params = clone
	end

	checkf(_isName(params.name), 'every theme needs a valid name')
	checkf(themes.db[params.name] == nil, 'found more than one theme called %s', params.name)

	checkf(_isNonNegInt(params.maxIterations), 'maxIterations should be > 0')
	checkf(_isNonNegInt(params.minVertices), 'minVertices should be > 0')
	checkf(_isNonNegInt(params.maxVertices), 'maxVertices should be > 0')
	checkf(params.minVertices < params.maxVertices, 'minVertices should be < maxVertices')
	checkf(_isNonNegInt(params.maxValence), 'maxValence should be > 0')

	checkf(_isPosNum(params.springStrength), 'springStrength should be > 0')
	checkf(_isPosNum(params.edgeLength), 'edgeLength should be > 0')
	checkf(_isPosNum(params.repulsion), 'repulsion should be > 0')
	checkf(_isPosNum(params.maxDelta), 'maxDelta should be > 0')
	checkf(_isPosNum(params.convergenceDistance), 'convergenceDistance should be > 0')

	checkf(_isNonNegInt(params.minExtent), 'minExtent should be > 0')
	checkf(_isNonNegInt(params.maxExtent), 'maxExtent should be > 0')
	checkf(params.minExtent < params.maxExtent, 'minExtent should be < maxExtent')
	checkf(_isNonNegInt(params.radiusFudge), 'radiusFudge should be > 0')
	
	checkf(_isPosNum(params.relaxSpringStrength), 'relaxSpringStrength should be > 0')
	checkf(_isPosNum(params.relaxEdgeLength), 'relaxEdgeLength should be > 0')
	checkf(_isPosNum(params.relaxRepulsion), 'relaxRepulsion should be > 0')
	checkf(_isPosNum(params.relaxMaxDelta), 'relaxMaxDelta should be > 0')
	checkf(_isPosNum(params.relaxConvergenceDistance), 'relaxConvergenceDistance should be > 0')

	-- Now we find the ruleset data.
	local userRulesetPath = string.format("rulesets/%s", params.name)
	local packageRulesetPath = string.format("src/resources/rulesets/%s", params.name)
	params.path = userRulesetPath

	local readPath = userRulesetPath
	if not love.filesystem.isFile(readPath) then
		readPath = packageRulesetPath
	end

	if love.filesystem.isFile(readPath) then
		local file = love.filesystem.newFile(readPath)
		file:open('r')
		local code = file:read()
		file:close()

		local result, msg = loadstring(code)

		if result then
			params.ruleset = result

			-- Make sure there's a copy in the user data.
			if readPath ~= userRulesetPath then
				themes.saveRuleset(params, result())
			end			
		end
	end

	-- If there is no ruleset we need an empty one.
	if not params.ruleset then
		params.ruleset = loadstring(_emptyRuleset)

		themes.saveRuleset(params, params.ruleset())
	end

	themes.db[params.name] = params
	local sortedDB = themes.sortedDB
	sortedDB[#sortedDB+1] = params

	table.sort(sortedDB,
		function ( lhs, rhs )
			return lhs.name < rhs.name
		end)
end

-------------------------------------------------------------------------------

local base = {
	-- Parameters for GraphGrammar:build()
	maxIterations = 10,
	minVertices = 1,
	maxVertices = 20,
	maxValence = 8,

	-- Graph drawing parameters to use during construction.
	springStrength = 1,
	edgeLength = 100,
	repulsion = 1,
	maxDelta = 0.5,
	convergenceDistance = 4,

	-- TODO: Parameters that govern vertex room assignment.
	-- - Need someway to choose the roomgen.
	-- - There is a fundamental value called margin (the shortest distance
	--   between points between) that needs to be defined.
	-- - Currently 
	minExtent = 3,
	maxExtent = 12,
	radiusFudge = 1, -- TODO: this is being used as the margin.

	


	-- Graph drawing parameters to use during relaxation.
	relaxSpringStrength = 10,
	relaxEdgeLength = 100,
	relaxRepulsion = 0.05,
	relaxMaxDelta = 0.5,
	relaxConvergenceDistance = 0.01,
}


Theme {
	template = base,
	name = 'default',

	maxVertices = 10,
	relaxEdgeLength = 50,
}

Theme {
	template = base,
	name = 'quads',
}

Theme {
	template = base,
	name = 'silly',
}

Theme {
	template = base,
	name = 'tree',
}

Theme {
	template = base,
	name = 'catacomb',

	relaxEdgeLength = 50,
}

Theme {
	template = base,
	name = 'spiral',
}