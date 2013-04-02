require 'Graph'
require 'graph2D'
require 'terrains'

fringes = {}

local style = {}

-- params = {
--     depth = <number>,
--     terrain = <terrain>,
-- }
function style.solid( params, graph, sources, mask )
	local depth = params.depth
	local terrain = params.terrain

	assert(depth > 0 and depth < math.huge)
	assert(math.floor(depth) == depth)
	assert(isTerrain(terrain))

	local vertexFilter = 
		function ( vertex )
			return not mask[vertex] 
		end

	local fringe = graph:vertexFilteredMultiSourceDistanceMap(source, depth, vertexFilter)

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
function style.random( params, graph, sources, mask )
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

	local fringe = graph:vertexFilteredMultiSourceDistanceMap(source, depth, vertexFilter)

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
function style.organic( params, graph, sources, mask )
	local depth = params.depth
	local seeding = params.seeding
	local terrain = params.terrain

	assert(depth > 0 and depth < math.huge)
	assert(math.floor(depth) == depth)
	assert(0 < seeding and seeding < 1)
	assert(isTerrain(terrain))

	local vertexFilter = 
		function ( vertex )
			return not mask[vertex] 
		end

	local fringe = graph:vertexFilteredMultiSourceDistanceMap(source, depth, vertexFilter)

	local result = {}

	for probe = 1, depth do
		for vertex, distance in pairs(fringe) do
			if distance == probe then
			end
		end
	end

	return result
end


local function _sequence( defs, graph, sources, mask )
	local result = {}

	-- We will be changing the sources and mask tables so make a copy.
	sources = table.copy(sources)
	mask = table.copy(mask)

	for index, params in ipairs(defs) do
		local func = style[params[1]]
		assert(func)

		local fringe = func(params, graph, sources, mask)

		for vertex, terrain in pairs(fringe) do
			result[vertex] = terrain

			-- We don't want subsequent steps of the sequence to change what
			-- previous steps have chosen so we add to the sources and mask.
			sources[vertex] = true
			mask[vertex] = true
		end
	end

	return result
end
