
Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
	local result = {
		jobs = {},
		index = 1,
		ticks = 0,
		removed = {},
	}

	setmetatable(result, Scheduler)

	return result
end

-- The func param is a function that takes arbitrary arguments (passed via the
-- run() method) and is expected to return two values:
--
--     local cost, result = func(...)
--
-- The cost is an integer >= 0 that denotes how many ticks are required until
-- the func is next called. A cost of 0 denotes an instanteous action and is
-- handled specially by run().
--
-- The result return value is appended to an array of results returned by run()
-- and can be anything, including nil.
--
-- The job based on the func will not be called on the current tick but on the
-- next one.
function Scheduler:add( func )
	local job = {
		ticks = 0,
		func = func,
		release = nil,
	}

	job.remove =
		function ()
			self:remove(job)
		end

	table.insert(self.jobs, self.index, job)
	self.index = self.index + 1

	return job
end

-- This can be directly or indirectly called by a job func.
function Scheduler:remove( job )
	self.removed[job] = true
end

function Scheduler:_tidy()
	local jobs = self.jobs
	local removed = self.removed

	for i = #jobs, 1, -1 do
		if removed[jobs[i]] then
			if i < self.index then
				self.index = self.index - 1
			end

			table.remove(jobs, i)
		end
	end

	self.removed = {}
end

--
-- Runs through jobs in registered order decrementing ticks counters and 
-- calling the respective func when the tick is 0. Any parameters passed to
-- run() are passed to the job func.
--
--     local complete, ticks, results = scheduler:run(...)
-- 
-- complete: false when a func returned a cost of 0, true otherwise
-- ticks:    the number of passes through all jobs before returning, can be 0
--           if complete is false.
-- results:  an array of all results returned from job func calls in
--           chronological order
--
-- So run() returns on one of two cases:
-- - A job func returned a cost of 0, which signifies an instantneous action.
-- - An entire pass of the jobs was done and at least one job func was called.
--
-- If a job func returns a cost of 0 run() will return immediately and when
-- run() is next called it will start from the same job.
-- 
function Scheduler:run( ... )
	local results = {}

	if self.ticks == 0 then
		self.index = 1
	end

	local jobs = self.jobs
	local removed = self.removed
	local called = false
	local ticks = self.ticks

	-- while (not called or self.index ~= 1) and #jobs > 0 do
	while #jobs > 0 do
		local job = jobs[self.index]

		if not removed[job] then
			if job.ticks > 1 then
				job.ticks = job.ticks - 1
			else
				local cost, result = job.func(...)

				assert(type(cost) == 'number' and cost >= 0 and math.floor(cost) == cost)

				results[#results+1] = result
				called = true

				if cost == 0 then
					self:_tidy()

					return false, self.ticks - ticks, results
				end

				job.ticks = cost
			end
		end

		self.index = self.index + 1

		if self.index > #jobs then
			self.index = 1
			self.ticks = self.ticks + 1
	
			if called then
				break
			end
		end
	end

	self:_tidy()

	return true, self.ticks - ticks, results
end

if false then
	local sched = Scheduler.new()


	local func1 =
		function ( sched )
			local cost = 2
			print('job1', sched.ticks)
			return cost
		end

	local func2 =
		function ( sched )
			local cost = 2
			print('job2', sched.ticks)
			return cost
		end

	local job1 = sched:add(func1)
	local job2 = sched:add(func2)

	for i = 1, 3 do
		local clean, ticks, results = sched:run(sched)
		print(string.format("clean:%s dt:%s ticks:%d", tostring(clean), ticks, sched.ticks))

		-- for i, j in ipairs(sched.jobs) do
		-- 	print('', i, j.ticks)
		-- end

		print()
	end

	sched = Scheduler.new()

	for i = 1, 5 do
		local count = i
		local job
		job = sched:add(
			function ()
				print('job' .. tostring(i))
				count = count - 1

				if count == 0 then
					print('suicide job' .. tostring(i))
					sched:remove(job)
				end

				return 1
			end)
	end

	for i = 1, 10 do
		print(sched:run())
	end

	sched = Scheduler.new()

	local block = true

	sched:add(
		function ()
			block = not block

			print('block', block)

			if block then
				return 0
			else
				return 2
			end
		end)

	sched:add(
		function ()
			print('job1')

			return 2
		end)

	for i = 1, 5 do
		print(sched:run())
	end
end




