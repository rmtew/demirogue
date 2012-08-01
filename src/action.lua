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

			return true
		end

	return 5, {
		sync = false,
		plan = plan,
	}
end

function action.melee( level, actor, target )
	local duration = 0.5
	local impact = duration * 0.25
	local recover = impact + (duration - impact) * 0.25

	assert(impact < recover)
	assert(recover < duration)

	local to = Vector.to(actor, target)
	local toLength = to:length()

	local plan =
		function ( time )
			if time >= duration then
				actor.offset[1], actor.offset[2] = 0, 0
				target.offset[1], target.offset[2] = 0, 0
				
				target:die()

				return false
			end

			if time <= impact then
				local bias = time / impact
				bias = bias * bias
				actor.offset[1] = to[1] * bias * 0.75
				actor.offset[2] = to[2] * bias * 0.75
			else
				local bias = 1 - ((time - impact) / (duration - impact))
				bias = bias * bias
				actor.offset[1] = to[1] * bias * 0.75
				actor.offset[2] = to[2] * bias * 0.75
			end

			if impact <= time then
				if time <= recover then
					local bias = (time - impact) / (recover - impact)
					bias = math.sqrt(bias)

					target.offset[1] = to[1] * bias * 0.2
					target.offset[2] = to[2] * bias * 0.2
				else
					local bias = 1 - ((time - recover) / (duration - recover))
					bias = bias * bias

					target.offset[1] = to[1] * bias * 0.2
					target.offset[2] = to[2] * bias * 0.2
				end
			end

			return true
		end

	return 5, {
		sync = true,
		plan = plan,
	}
end


-- The actor leaps towards the target vertex. If there's an actor at the target
-- vertex it is attacked and the actor returns to it's starting vertex. If the
-- target vertex is unoccupied the actor lands at the target vertex.
function action.leap( level, actor, target )
	local attack = target.actor ~= nil

	local impact = 0.25
	local recoil = 0.25
	local duration = (attack) and impact + 2 * recoil or impact
	local height = 30

	local to = Vector.to(actor, target)
	local toLength = to:length()

	if not attack then
		local success = actor:moveTo(target)
		assert(success)
	end

	local plan =
		function ( time )
			if time >= duration then
				if not attack then
					actor.offset[1], actor.offset[2] = 0, 0
					actor[1], actor[2] = target[1], target[2]
				else
					local offset = target.actor.offset
					offset[1], offset[2] = 0, 0
					target.actor:die()
				end

				return false
			end

			if time <= impact then
				local bias = time / impact
				local t = 2 * (bias - 0.5)
				local y = -height * (1 - (t*t))
				-- bias = bias * bias
				actor.offset[1] = to[1] * bias
				actor.offset[2] = y + (to[2] * bias)
			else
				assert(attack)

				local bias = 1 - ((time - impact) / (duration - impact))
				local t = 2 * (bias - 0.5)
				local y = -height * (1 - (t*t))
				-- bias = bias * bias
				actor.offset[1] = to[1] * bias
				actor.offset[2] = y + (to[2] * bias)
			end

			if attack and impact <= time then
				if time <= recoil then
					local bias = (time - impact) / (recoil - impact)
					bias = math.sqrt(bias)

					target.actor.offset[1] = to[1] * bias * 0.2
					target.actor.offset[2] = to[2] * bias * 0.2
				else
					local bias = 1 - ((time - recoil) / (duration - recoil))
					bias = bias * bias

					target.actor.offset[1] = to[1] * bias * 0.2
					target.actor.offset[2] = to[2] * bias * 0.2
				end
			end

			return true
		end

	return 5, {
		sync = true,
		plan = plan,
	}
end

for name, func in pairs(action) do
	action[name] =
		function ( ... )
			local cost, plan = func(...)
			plan.name = name
			return cost, plan
		end
end
