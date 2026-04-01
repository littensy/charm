local Charm = require("../packages/charm/src")
local bench = require("./bench")

local computed = Charm.computed
local mapped = Charm.mapped
local signal = Charm.signal

type Key = number
type Value = number

local count = 512
local initialState: { [Key]: Value } = table.create(count, 0)

local function expensiveOperation()
	for _ = 1, 100 do
		continue
	end
end

local function simpleMapped(
	source: () -> { [Key]: Value },
	mapper: (Value, Key) -> (Value, Key?)
): () -> { [Key]: Value }
	return computed(function()
		local state = source()
		local nextState = {}

		for keyIn, valueIn in state do
			local valueOut, keyOut = mapper(valueIn, keyIn)
			nextState[if keyOut == nil then keyIn else keyOut] = valueOut
		end

		return nextState
	end)
end

local function updateRandomly(updateChance: number): ({ [Key]: Value }) -> { [Key]: Value }
	return function(state)
		local nextState = table.clone(state)
		for key in state do
			if math.random() < updateChance then
				nextState[key] += 1
			end
		end
		return nextState
	end
end

for _, updateChance in { 0.1, 0.5, 1 } do
	local function mapper(value: Value, key: Key): (Value, Key?)
		expensiveOperation()
		return value + 1, key + 1
	end

	bench.run(`mapped {updateChance}`, function()
		local src, setSrc = signal(initialState)
		local out = mapped(src, mapper)

		bench.profilebegin("init")
		out()
		bench.profileend()

		setSrc(updateRandomly(updateChance))

		bench.profilebegin("update")
		out()
		bench.profileend()
	end)

	bench.run(`control {updateChance}`, function()
		local src, setSrc = signal(initialState)
		local out = simpleMapped(src, mapper)

		bench.profilebegin("init")
		out()
		bench.profileend()

		setSrc(updateRandomly(updateChance))

		bench.profilebegin("update")
		out()
		bench.profileend()
	end)
end
