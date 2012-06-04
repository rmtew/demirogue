--
-- action.lua
--
-- NOTE: - The return plan func MUST be called at least once and until it returns false.
--

require 'Actor'
require 'Vector'

action = {}



function action.search( level, actor )
	local duration = 1
	local radius = 10
	local origin = Vector.new(actor)

	local plan =
		function ( time )
			if time >= duration then
				actor[1], actor[2] = origin[1], origin[2]

				return false
			end

			actor[1] = origin[1] + (radius * math.cos(time * math.pi * 2))
			actor[2] = origin[2] + (radius * math.sin(time * math.pi * 2))

			return true
		end

	return 5, {
		sync = false,
		plan = plan,
	}	
end

function action.move( level, actor, target )
	assert(actor.vertex)
	assert(not target.actor)

	local duration = 0.25
	local origin = Vector.new(actor)
	local to = Vector.to(actor, target)

	local success = actor:moveTo(target)
	assert(success)

	local plan =
		function ( time )
			if time >= duration then
				actor[1], actor[2] = target[1], target[2]

				return false
			end

			local bias = time / duration
			bias = math.sqrt(bias)

			actor[1] = origin[1] + (bias * to[1])
			actor[2] = origin[2] + (bias * to[2])

			return true
		end

	return 5, {
		sync = false,
		plan = plan,
	}
end

