CircularBuffer = {buf={}, capacity=0, head=0}

function CircularBuffer:new(cap)
	o = {}
	setmetatable(o, self)
	self.__index = self
	self.cap = cap
	for i = 1,cap do
		self.buf[i] = 0
	end
	return o
end

function CircularBuffer:push(val)
	self.head = (self.head % self.cap) + 1
	self.buf[self.head] = val
end

function CircularBuffer:get(index)
	index = self.head + index
	while index < 1 do
		index = index + 4
	end
	return self.buf[index]
end
