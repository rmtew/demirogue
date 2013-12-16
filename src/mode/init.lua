--
-- mode/init.lua
--

local state = require 'lib/state'
require 'mode/VoronoiMode'
require 'mode/GraphMode'
local schema, VoronoiMode = require 'lib/mode' { 'VoronoiMode' }

local function export()
	return state.machine(schema, VoronoiMode)
end

return export