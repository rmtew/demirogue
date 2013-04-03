require 'Graph'
require 'graph2D'
require 'terrains'

fringes = {}

local styles = {}

function styles.empty( params, graph, sources, mask )
	return {}
end

-- params = {
--     depth = <number>,
--     terrain = <terrain>,
-- }
function styles.solid( params, graph, sources, mask )
	local depth = params.depth
	local terrain = params.terrain

	assert(depth > 0 and depth < math.huge)
	assert(math.floor(depth) == depth)
	assert(isTerrain(terrain))

	local vertexFilter = 
		function ( vertex )
			return not mask[vertex] 
		end

	local fringe = graph:vertexFilteredMultiSourceDistanceMap(sources, depth, vertexFilter)

	local result = {}

	for vertex, depth in pairs(fringe) do
		if depth > 0 then
			result[vertex] = terrain
		end
	end

	return result
end

-- params = {
--     depth = <number>,
--     probability = (0..1),
--     terrain = <terrain>,
-- }
function styles.random( params, graph, sources, mask )
	local depth = params.depth
	local probability = params.probability
	local terrain = params.terrain

	assert(depth > 0 and depth < math.huge)
	assert(math.floor(depth) == depth)
	assert(0 < probability and probability < 1)
	assert(isTerrain(terrain))

	local vertexFilter = 
		function ( vertex )
			return not mask[vertex] 
		end

	local fringe = graph:vertexFilteredMultiSourceDistanceMap(sources, depth, vertexFilter)

	local result = {}

	for vertex, depth in pairs(fringe) do
		local r = math.random()
		if depth > 0 and r < probability then
			result[vertex] = terrain
		end
	end

	return result
end

-- params = {
--     depth = <number>,
--     seeding = (0..1),
--     terrain = <terrain>,
-- }
function styles.organic( params, graph, sources, mask )
	local depth = params.depth
	local seeding = params.seeding
	local terrain = params.terrain

	assert(depth > 0 and depth < math.huge)
	assert(math.floor(depth) == depth)
	assert(0 < seeding and seeding < 1)
	assert(isTerrain(terrain))

	-- We will be changing the sources table so make a copy.
	local accumSources = table.copy(sources)

	local vertexFilter = 
		function ( vertex )
			return not mask[vertex]
		end

	local result = {}

	for iteration = 1, depth do
		local fringe = graph:vertexFilteredMultiSourceDistanceMap(accumSources, 1, vertexFilter)

		for vertex, distance in pairs(fringe) do
			if distance == 1 then
				local r = math.random()

				if r < seeding then
					result[vertex] = terrain

					accumSources[vertex] = true
				end
			end
		end
	end

	return result
end

-- params = {
--     { params }+
-- }
function styles.sequence( params, graph, sources, mask )
	local result = {}

	-- We will be changing the sources and mask tables so make a copy.
	local accumSources = table.copy(sources)
	local accumMask = table.copy(mask)

	for index, subparams in ipairs(params) do
		local style = styles[subparams.style]
		assert(style)

		local fringe = style(subparams, graph, accumSources, accumMask)

		for vertex, terrain in pairs(fringe) do
			result[vertex] = terrain

			-- We don't want subsequent steps of the sequence to change what
			-- previous steps have chosen so we add to the sources and mask.
			accumSources[vertex] = true
			accumMask[vertex] = true
		end
	end

	return result
end

fringes.empty = {
	style = 'empty',
}

fringes.graniteWall = {
	style = 'organic',
	depth = 3,
	seeding = 0.5,
	terrain = terrains.granite,
}

fringes.abyss = {
	style = 'organic',
	depth = 10,
	seeding = 0.75,
	terrain = terrains.abyss,
}

fringes.castle = {
	style = 'sequence',
	{
		style = 'solid',
		depth = 1,
		terrain = terrains.granite,
	},
	{
		style = 'solid',
		depth = 2,
		terrain = terrains.water,
	},
	{
		style = 'solid',
		depth = 1,
		terrain = terrains.unwalkableDirt,
	},
	{
		style = 'organic',
		depth = 5,
		seeding = 0.75,
		terrain = terrains.tree,
	},
}

for name, params in pairs(fringes) do
	params.name = name
	local style = params.style
	assert(style)
	assertf(styles[style], 'unknown fringe style %s', tostring(style))
end

local _inverse = table.inverse(fringes)

function isFringe( value )
	return _inverse[value] ~= nil
end

function calcFringe( fringe, graph, sources, mask )
	local style = styles[fringe.style]
	assert(style)

	return style(fringe, graph, sources, mask)
end
