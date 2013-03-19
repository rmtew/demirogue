
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

for name, params in pairs(terrains) do
	params.name = name
end
