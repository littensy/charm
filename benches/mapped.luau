local Charm = require("../packages/charm/src")
local bench = require("./bench")

local atom = Charm.atom
local computed = Charm.computed
local mapped = Charm.mapped
local setCurrentSub = Charm.core.setCurrentSub

type Entry = { number }

local count = 512
local initialState: { Entry } = table.create(count)

for i = 1, count do
	initialState[i] = table.create(64, i)
end

local function mapper(value: Entry, key: number): (Entry, number)
	return table.clone(value), key + 1
end

local function simpleMapped(source: () -> { Entry }, mapper: (Entry, number) -> (Entry, number)): () -> { Entry }
	return computed(function()
		local state = source()
		local nextState = {}

		for index, value in state do
			local currentSub = setCurrentSub(nil)
			local success, valueOut, keyOut = pcall(mapper, value, index)
			setCurrentSub(currentSub)

			if success then
				nextState[keyOut] = valueOut
			end
		end

		return state
	end)
end

local function updatePercentage(percent: number): ({ Entry }) -> { Entry }
	return function(state)
		local nextState = table.clone(state)
		for index, value in state do
			if math.random() < percent then
				nextState[index] = table.clone(value)
			end
		end
		return nextState
	end
end

for _, percent in { 0.1, 0.5, 1 } do
	bench.run(`mapped {percent}`, function()
		local src = atom(initialState)
		local out = mapped(src, mapper)

		bench.profilebegin("init")
		out()
		bench.profileend()
		src(updatePercentage(percent))
		bench.profilebegin("update")
		out()
		bench.profileend()
	end)

	bench.run(`control {percent}`, function()
		local src = atom(initialState)
		local out = simpleMapped(src, mapper)

		bench.profilebegin("init")
		out()
		bench.profileend()
		src(updatePercentage(percent))
		bench.profilebegin("update")
		out()
		bench.profileend()
	end)
end
