--
-- action.lua
--
-- NOTE: - The return plan func MUST be called at least once and until it returns false.
--

require 'Actor'
require 'Vector'

action = {}



function action.search( level, actor )
	local duration = 0.25
	local radius = 10

	local plan =
		function ( time )
			if time >= duration then
				actor.offset[1], actor.offset[2] = 0, 0

				return false
			end

			local disp = radius * math.sin(math.pi * (time / duration))

			actor.offset[1] = disp * math.cos(time * math.pi * 5)
			actor.offset[2] = disp * math.sin(time * math.pi * 5)

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
	local hops = 2
	local height = 10

	local success = actor:moveTo(target)
	assert(success)

	local plan =
		function ( time )
			if time >= duration then
				actor[1], actor[2] = target[1], target[2]
				actor.offset[1], actor.offset[2] = 0, 0

				return false
			end

			local bias = time / duration
			-- bias = math.sqrt(bias)

			-- actor[1] = origin[1] + (bias * to[1])
			-- actor[2] = origin[2] + (bias * to[2])

			actor[1] = origin[1] + (bias * to[1])
			actor[2] = origin[2] + (bias * to[2])
			actor.offset[1] = 0
			actor.offset[2] = -height * math.abs(math.sin(bias * math.pi * hops))

			print('actor.offset[2]',actor.offset[2])


			return true
		end

	return 5, {
		sync = false,
		plan = plan,
	}
end

function action.melee( level, actor, target )
	local duration = 0.25
	local impact = duration * 0.25

	local to = Vector.to(actor, target)
	local toLength = to:length()

	local plan =
		function ( time )
			if time >= duration then
				actor.offset[1], actor.offset[2] = 0, 0
				
				target:die()

				return false
			end

			if time <= impact then
				local bias = time / impact
				bias = bias * bias
				actor.offset[1] = to[1] * bias * 0.8
				actor.offset[2] = to[2] * bias * 0.8
			else
				local bias = 1 - ((time - impact) / (duration - impact))
				bias = bias * bias
				actor.offset[1] = to[1] * bias * 0.8
				actor.offset[2] = to[2] * bias * 0.8
			end

			return true
		end

	return 5, {
		sync = true,
		plan = plan,
	}
end

