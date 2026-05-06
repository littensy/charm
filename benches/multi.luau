local Charm = require("../packages/charm/src")
local bench = require("./bench")

type Atom<T> = Charm.Atom<T>

local signal = Charm.atom
local computed = Charm.computed
local effect = Charm.effect

local function busy(): number
	local a = 0
	for i = 1, 100 do
		a += 1
	end
	return a
end

do
	local head = signal(0)
	local computed1 = computed(function()
		return head()
	end)
	local computed2 = computed(function()
		computed1()
		return 0
	end)
	local computed3 = computed(function()
		busy() -- heavy computation
		return computed2() + 1
	end)
	local computed4 = computed(function()
		return computed3() + 2
	end)
	local computed5 = computed(function()
		return computed4() + 3
	end)
	effect(function()
		computed5()
		busy() -- heavy side effect
	end)

	bench.run("avoidablePropagation", function()
		head(1)
		assert(computed5() == 6)
		for i = 0, 999 do
			head(i)
		end
		assert(computed5() == 6)
	end)
end

do
	local head = signal(0)
	local double = computed(function()
		return head() * 2
	end)
	local inverse = computed(function()
		return -head()
	end)
	local current = computed(function()
		local result = 0
		for i = 0, 19 do
			result += if head() % 2 == 1 then double() else inverse()
		end
		return result
	end)

	local callCounter = 0
	effect(function()
		current()
		callCounter += 1
	end)

	bench.run("unstable", function()
		head(1)
		assert(current() == 40)
		callCounter = 0
		for i = 0, 99 do
			head(i)
		end
		assert(callCounter == 100)
	end)
end

do
	local head = signal(0)
	local double = computed(function()
		return head() * 2
	end)
	local inverse = computed(function()
		return -head()
	end)
	local current = computed(function()
		local result = 0
		for i = 0, 19 do
			result += if head() % 2 == 1 and i % 2 == 1 then double() else inverse()
		end
		return result
	end)

	local callCounter = 0
	effect(function()
		current()
		callCounter += 1
	end)

	bench.run("unstable 50%", function()
		head(1)
		assert(current() == 10)
		callCounter = 0
		for i = 0, 99 do
			head(i)
		end
		assert(callCounter == 100)
	end)
end

do
	local head = signal(0)
	local last: () -> number = head
	local callCounter = 0

	for i = 0, 49 do
		local current = computed(function()
			return head() + i
		end)
		local current2 = computed(function()
			return current() + 1
		end)
		effect(function()
			current2()
			callCounter += 1
		end)
		last = current2
	end

	bench.run("broadPropagation", function()
		head(1)
		callCounter = 0
		for i = 0, 49 do
			head(i)
			assert(last() == i + 50)
		end
		assert(callCounter == 50 * 50)
	end)
end

do
	local heads = {}
	for index = 0, 99 do
		heads[index] = signal(0)
	end

	local mux = computed(function()
		local result = {}
		for index = 0, 99 do
			result[index] = heads[index]()
		end
		return result
	end)

	local splited = {}
	for index = 0, 99 do
		local x = computed(function()
			return mux()[index]
		end)
		splited[index] = computed(function()
			return x() + 1
		end)
	end

	for _, x in splited do
		effect(function()
			x()
		end)
	end

	bench.run("mux", function()
		for i = 0, 9 do
			heads[i](i)
			assert(splited[i]() == i + 1)
		end
		for i = 0, 9 do
			heads[i](i * 2)
			assert(splited[i]() == i * 2 + 1)
		end
	end)
end
