
terrains = {}

-- terrain.<name> = {
--     walkable = <boolean>,
--     colour = { [0.255], [0.255], [0.255], [0.255] } : { R, G, B, A }
-- }

terrains.floor = {
	walkable = true,
	colour = { 184, 118, 61, 255 },
}

terrains.corridor = {
	walkable = true,
	colour = { 0, 128, 128, 255 },
}

terrains.wall = {
	walkable = false,
	colour = { 64, 64, 64, 255 },	
}

terrains.tree = {
	walkable = false,
	colour = { 72, 163, 103, 255 },
}

terrains.water = {
	walkable = false,
	colour = { 0, 121, 194, 255 }
}

terrains.lava = {
	walkable = false,
	colour = { 255.5, 149, 0, 255 }
}

terrains.abyss = {
	walkable = false,
	colour = { 55, 4, 112, 255 }
}

for name, params in pairs(terrains) do
	params.name = name
end

local _inverse = table.inverse(terrains)

function isTerrain( value )
	return _inverse[value] ~= nil
end