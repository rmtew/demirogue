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
		end,

	local fringe = graph:vertexFilteredMultiSourceDistanceMap(source, depth, vertexFilter)

	local result = {}

	for vertex, depth in pairs(fringe) do
		if depth > 0 then
			result[vertex] = terrain
		end
	end

	return result
end

