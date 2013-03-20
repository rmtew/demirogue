--
-- themes.lua
--

require 'roomgen'
require 'terrains'

themes = {
	db = {},
	sortedDB = {},
}

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

function themes.load()
	if not love.filesystem.isDirectory('rulesets') then
		love.filesystem.mkdir('rulesets')
	end

	for name, theme in pairs(themes.db) do
		-- Now we find the ruleset data.
		local userRulesetPath = string.format("rulesets/%s", name)
		local packageRulesetPath = string.format("resources/rulesets/%s", name)
		theme.path = userRulesetPath

		local readPath = userRulesetPath
		if not love.filesystem.isFile(readPath) then
			printf('[themes] %s is not in user storage', name)
			readPath = packageRulesetPath
		end

		if love.filesystem.isFile(readPath) then
			local file = love.filesystem.newFile(readPath)
			file:open('r')
			local code = file:read()
			file:close()

			local result, msg = loadstring(code)

			if result then
				theme.ruleset = result

				-- Make sure there's a copy in the user data.
				if readPath ~= userRulesetPath then
					local stack = themes.loadRuleset(theme)
					themes.saveRuleset(theme, stack)
				end			
			end
		else
			printf('[themes] %s is not in package storage', name)
		end

		-- If there is no ruleset we need an empty one.
		if not theme.ruleset then
			printf('[themes] %s is empty', name)
			theme.ruleset = loadstring(_emptyRuleset)

			local stack = themes.loadRuleset(theme)

			themes.saveRuleset(theme, stack)
		end
	end
end

function themes.saveRuleset( theme, stack )
	-- Make a nice to save version of the state.

	-- { level }+
	-- level = { leftGraph = graph, rightGraph = graph, map = map }
	-- graph = { vertices = { vertex }+, edges = { edge }+ }
	-- edge = { <index>, <index>, cosmetic = <boolean>, subdivide = <boolean> }
	-- vertex = {
	--     <x>,
	--     <y>,
	--     side = 'left'|'right',
	--     tag = <string>,
	--     mapped = <boolean>|nil,
	--     cosmetic = <boolean>,
	-- }
	-- map = { [<index>] = <index> }*

	local function _vertex( vertex )
		if vertex.side == 'left' then
			return {
				vertex[1],
				vertex[2],
				side = 'left',
				tags = table.copy(vertex.tags),
				lock = vertex.lock and true or false,
				cosmetic = vertex.cosmetic and true or false,
			}
		else
			return { 
				vertex[1],
				vertex[2],
				side = 'right',
				tag = vertex.tag,
				mapped = vertex.mapped and true or false,
				cosmetic = vertex.cosmetic and true or false,
			}
		end
	end

	local function _graph( graph )
		local vertexIndices = {}
		local nextVertexIndex = 1
		local vertices = {}

		for vertex, _ in pairs(graph.vertices) do
			local copy = _vertex(vertex)
			vertices[nextVertexIndex] = copy
			vertexIndices[vertex] = nextVertexIndex
			nextVertexIndex = nextVertexIndex + 1
		end

		local edges = {}

		for edge, endverts in pairs(graph.edges) do
			local vertex1Index = vertexIndices[endverts[1]]
			local vertex2Index = vertexIndices[endverts[2]]
			local cosmetic = edge.cosmetic and true or false
			local subdivide = edge.subdivide and true or false

			edges[#edges+1] = {
				vertex1Index,
				vertex2Index,
				cosmetic = cosmetic,
				subdivide = subdivide,
			}
		end

		return { vertices = vertices, edges = edges }, vertexIndices
	end

	local function _level( level )
		local leftGraph, leftVertexIndices = _graph(level.leftGraph)
		local rightGraph, rightVertexIndices = _graph(level.rightGraph)

		local map = {}

		for leftVertex, rightVertex in pairs(level.map) do
			map[leftVertexIndices[leftVertex]] = rightVertexIndices[rightVertex]
		end

		return {
			leftGraph = leftGraph,
			rightGraph = rightGraph,
			map = map
		}
	end

	local levels = {}

	for index, level in ipairs(stack) do
		local copy = _level(level)
		levels[index] = copy
	end

	local code = table.compile(levels)

	local ruleset = loadstring(code)
	assert(ruleset)

	theme.ruleset = ruleset

	local file = love.filesystem.newFile(theme.path)
	local success = file:open('w')
	assertf(success, 'could not open %s', theme.path)
	file:write(code)
	file:close()
end

function themes.loadRuleset( theme )
	-- Turn the saved version of the state into a runtime usable version.

	local function _vertex( vertex )
		if vertex.side == 'left' then
			return {
				vertex[1],
				vertex[2],
				side = 'left',
				tags = table.copy(vertex.tags),
				lock = vertex.lock and true or false,
				cosmetic = vertex.cosmetic and true or false,
			}
		else
			return { 
				vertex[1],
				vertex[2],
				side = 'right',
				tag = vertex.tag,
				mapped = vertex.mapped and true or false,
				cosmetic = vertex.cosmetic and true or false,
			}
		end
	end

	local function _graph( graph )
		local vertexIndices = {}

		local result = Graph.new()

		for index, vertex in ipairs(graph.vertices) do
			local copy = _vertex(vertex)
			result:addVertex(copy)
			vertexIndices[index] = copy
		end

		for _, edge in pairs(graph.edges) do
			local side = vertexIndices[edge[1]].side
			local cosmetic = edge.cosmetic and true or false
			local subdivide = edge.subdivide and true or false
			local newEdge = {
				side = side,
				cosmetic = cosmetic,
				subdivide = subdivide,
			} 
			result:addEdge(newEdge, vertexIndices[edge[1]], vertexIndices[edge[2]])
		end

		return result, vertexIndices
	end

	local function _level( level )
		local leftGraph, leftVertexIndices = _graph(level.leftGraph)
		local rightGraph, rightVertexIndices = _graph(level.rightGraph)

		local map = {}

		for leftVertexIndex, rightVertexIndex in pairs(level.map) do
			map[leftVertexIndices[leftVertexIndex]] = rightVertexIndices[rightVertexIndex]
		end

		return {
			leftGraph = leftGraph,
			rightGraph = rightGraph,
			map = map
		}
	end

	local data = theme.ruleset()

	local result = {}

	for index, level in ipairs(data) do
		local copy = _level(level)

		result[index] = copy
	end

	return result	
end

local function _calculateLengthFactors( level )
	local leftGraph = level.leftGraph
	local rightGraph = level.rightGraph

	local meanLeftEdgeLength = graph2D.meanEdgeLength(leftGraph)
	local meanRightEdgeLength = graph2D.meanEdgeLength(rightGraph)

	-- print('length factors', meanLeftEdgeLength, meanRightEdgeLength)

	local meanEdgeLength = meanLeftEdgeLength

	if meanEdgeLength == 0 then
		meanEdgeLength = meanRightEdgeLength
	end

	if meanEdgeLength > 0 then
		for rightEdge, rightEndVerts in pairs(rightGraph.edges) do
			if rightEdge.subdivide then
				local edgeLength = Vector.toLength(rightEndVerts[1], rightEndVerts[2])

				local lengthFactor = edgeLength / meanEdgeLength

				-- print(edgeLength, meanEdgeLength, lengthFactor)

				rightEdge.lengthFactor = lengthFactor
			end
		end
	end
end

function themes.rule( level )
	_calculateLengthFactors(level)

	local pattern = level.leftGraph
	local substitute = level.rightGraph
	local map = level.map
	local status, result = pcall(
		function ()
			return GraphGrammar.Rule.new(pattern, substitute, map)
		end)
	
	if status then
		return result
	else
		print(result)
		return nil, result
	end
end

function themes.rules( stack )
	local rules = {}
	local nextRuleId = 1

	for _, level in ipairs(stack) do
		local rule = themes.rule(level)

		if rule then
			local name = string.format("rule%d", nextRuleId)
			printf('RULE %s!', name)
			nextRuleId = nextRuleId + 1
			rules[name] = rule
		else
			print('RULE FAIL')
		end
	end

	print('RULEZ', #stack, table.count(rules))

	return rules
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

	checkf(_isNonNegInt(params.margin), 'margin should be > 0')
	checkf(_isNonNegInt(params.minExtent), 'minExtent should be > 0')
	checkf(_isNonNegInt(params.maxExtent), 'maxExtent should be > 0')
	checkf(params.minExtent < params.maxExtent, 'minExtent should be < maxExtent')
	checkf(_isNonNegInt(params.radiusFudge), 'radiusFudge should be > 0')
	checkf(type(params.roomgen) == 'function', 'roomgen should be a function')
	
	local tags = params.tags

	if tags then
		for tag, values in pairs(tags) do
			local minExtent = values.minExtent
			local maxExtent = values.maxExtent
			local roomgen = values.roomgen
			local terrain = values.terrain
			local surround = values.surround

			checkf(_isNonNegInt(minExtent), 'tags.%s.minExtent should be > 0', tag)
			checkf(_isNonNegInt(maxExtent), 'tags.%s.maxExtent should be > 0', tag)
			checkf(minExtent < maxExtent, 'tags.%s.minExtent should be < tags.%s.maxExtent', tag, tag)
			checkf(type(roomgen) == 'function', 'tags.%s.roomgen should be a function', tag)
			checkf(isTerrain(terrain), 'tags.%s.terrain should be a valid terrain')
			checkf(isTerrain(surround), 'tags.%s.surround should be a valid terrain or nil')
		end
	end

	checkf(_isPosNum(params.relaxSpringStrength), 'relaxSpringStrength should be > 0')
	checkf(_isPosNum(params.relaxEdgeLength), 'relaxEdgeLength should be > 0')
	checkf(_isPosNum(params.relaxRepulsion), 'relaxRepulsion should be > 0')
	checkf(_isPosNum(params.relaxMaxDelta), 'relaxMaxDelta should be > 0')
	checkf(_isPosNum(params.relaxConvergenceDistance), 'relaxConvergenceDistance should be > 0')

	themes.db[params.name] = params
	local sortedDB = themes.sortedDB
	sortedDB[#sortedDB+1] = params

	table.sort(sortedDB,
		function ( lhs, rhs )
			return lhs.name < rhs.name
		end)

	-- Setup prevTheme and nextTheme fields.
	for index = 1, #sortedDB do
		local prevIndex = (index > 1) and index-1 or #sortedDB
		local nextIndex = (index < #sortedDB) and index+1 or 1

		local prevTheme = sortedDB[prevIndex]
		local nextTheme = sortedDB[nextIndex]

		local theme = sortedDB[index]
		theme.prevTheme = prevTheme
		theme.nextTheme = nextTheme
	end
end

local grid = roomgen.grid
local randgrid = roomgen.randgrid
local browniangrid = roomgen.browniangrid
local brownianhexgrid = roomgen.brownianhexgrid
local cellulargrid = roomgen.cellulargrid
local hexgrid = roomgen.hexgrid

local function choice( tbl )
	return
		function ( aabb, margin )
			local gen = tbl[math.random(1, #tbl)]

			return gen(aabb, margin)
		end
end

local function deck( tbl )
	local index = #tbl + 1
	return
		function ( aabb, margin )
			if index > #tbl then
				table.shuffle(tbl)
				index = 1
			end

			local gen = tbl[index]
			index = index + 1

			return gen(aabb, margin)
		end
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

	margin = 50,
	
	minExtent = 3,
	maxExtent = 12,
	radiusFudge = 1,
	-- roomgen = choice { browniangrid, grid, hexgrid, randgrid },
	roomgen = brownianhexgrid,

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
	relaxEdgeLength = 25,
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

	minExtent = 2,
	maxExtent = 5,

	tags = {
		a = {
			minExtent = 5,
			maxExtent = 8,
			roomgen = browniangrid,
			terrain = terrains.abyss,
			surround = terrains.abyss,
		},
	},

	relaxEdgeLength = 100,
}

Theme {
	template = base,
	name = 'spiral',
}