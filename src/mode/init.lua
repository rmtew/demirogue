--
-- mode/init.lua
--

local state = require 'lib/state'
require 'mode/VoronoiMode'
require 'mode/GraphMode'
require 'mode/ForceDrawMode'
local schema, init = require 'lib/mode' { 'VoronoiMode' }
local schema, init = require 'lib/mode' { 'ForceDrawMode' }

local function export()
	return state.machine(schema, init)
end

return export