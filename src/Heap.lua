
Heap = {}
Heap.__index = Heap
Heap.debug = false

function Heap.new( cmp )
	assert(type(cmp) == 'function')

	local result = {
		cmp = cmp,
	}

	setmetatable(result, Heap)

	return result
end

local function _children( index )
	local leftIndex = 2 * index
	return leftIndex, leftIndex + 1
end

local function _parent( index )
	return math.floor(index * 0.5)
end

function Heap:_check()
	local cmp = self.cmp

	for index, node in ipairs(self) do
		local leftIndex, rightIndex = _children(index)
		local left, right = self[leftIndex], self[rightIndex]

		if left ~= nil and not cmp(node, left) then
			print(self)
			error(string.format('not a heap - parent:%d left:%d', index, leftIndex))
		end

		if right ~= nil and not cmp(node, right) then
			print(self)
			error(string.format('not a heap - parent:%d right:%d', index, rightIndex))
		end
	end

	-- for i = 1, #self do
	-- 	for j = i + 1, #self do
	-- 		assert(self[i] ~= self[j])
	-- 	end
	-- end
end

function Heap:push( value )
	local cmp = self.cmp

	local lastIndex = #self+1
	self[lastIndex] = value

	local parentIndex = _parent(lastIndex)
	local index = lastIndex

	while parentIndex >= 1 do
		local heapy = cmp(self[parentIndex], value)

		if not heapy then
			self[parentIndex], self[index] = self[index], self[parentIndex]
			index = parentIndex
			parentIndex = _parent(parentIndex)
		else
			break
		end
	end

	if Heap.debug then
		self:_check()
	end
end


local function _maxHeapify( heap, index, cmp )
	local parent = heap[index]
	local leftIndex, rightIndex = _children(index)
	local left, right = heap[leftIndex], heap[rightIndex]

	local maxIndex = index

	if left and not cmp(parent, left) then
		maxIndex = leftIndex
	end

	if right and not cmp(heap[maxIndex], right) then
		maxIndex = rightIndex
	end

	if maxIndex ~= index then
		heap[index], heap[maxIndex] = heap[maxIndex], heap[index]
		_maxHeapify(heap, maxIndex, cmp)
	end
end

function Heap:pop()
	local size = #self
	assert(size >= 1)

	local result = self[1]
	self[1] = self[size]
	self[size] = nil

	_maxHeapify(self, 1, self.cmp)

	if Heap.debug then
		self:_check()
	end

	return result
end

function Heap:remove( value )
	for index, candidate in ipairs(self) do
		if value == candidate then
			local cmp = self.cmp

			local parentIndex = _parent(index)

			while parentIndex >= 1 do
				self[parentIndex], self[index] = self[index], self[parentIndex]
				index = parentIndex
				parentIndex = _parent(parentIndex)
			end

			self:pop()

			if Heap.debug then
				self:_check()
			end

			break
		end
	end
end

function Heap:__tostring()
	local parts = {}

	local aux =
		function ( aux, heap, index, tab )
			parts[#parts+1] = string.format('%s%s - #%d\n', string.rep('|-', tab), tostring(heap[index]), index)

			local leftIndex, rightIndex = _children(index)
			local left, right = self[leftIndex], self[rightIndex]

			if left then
				aux(aux, heap, leftIndex, tab+1)
			end

			if right then
				aux(aux, heap, rightIndex, tab+1)
			end
		end

	aux(aux, self, 1, 0)

	return table.concat(parts)
end


if Heap.debug then
	local numEntries = 50

	if os then
		math.randomseed(os.time())
		numEntries = 80000
	end

	local testCmp =
		function ( lhs, rhs )
			return lhs <= rhs
		end

	local test = Heap:new(testCmp)

	local entries = {}

	for i = 1, numEntries do
		local entry = math.random(1, 1000)
		test:push(entry)
		entries[#entries+1] = entry
	end

	print(test)

	local removed = {}

	for i = 1, math.floor(numEntries * 0.5) do
		local randomIndex = math.random(1, #entries)
		local entry = entries[randomIndex]
		test:remove(entry)
		removed[#removed+1] = entry
	end

	for _, v in ipairs(removed) do
		test:push(v)
	end

	local array = {}

	for i = 1, numEntries do
		array[#array+1] = test:pop()
	end

	for index = 1, numEntries -1 do
		assert(testCmp(array[index], array[index+1]))
	end
end



