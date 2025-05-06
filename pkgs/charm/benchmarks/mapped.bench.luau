local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local atom = Charm.atom
local computed = Charm.computed
local mapped = Charm.mapped

type Person = {
	name: string,
	age: number,
}

local personCount = 1000
local initialState: { Person } = table.create(personCount)

for i = 1, personCount do
	initialState[i] = {
		name = "Person " .. i,
		age = math.random(1, 100),
	}
end

local function mapper(person: Person): Person
	return {
		name = person.name .. "!",
		age = person.age + 1,
	}
end

local function simpleMapped(source: () -> { Person }): () -> { Person }
	return computed(function()
		local state = table.clone(source())
		for index, person in state do
			state[index] = mapper(person)
		end
		return state
	end)
end

local function updatePercentageOfPeople(percent: number): ({ Person }) -> { Person }
	return function(state)
		local nextState = table.clone(state)
		for index, person in state do
			if math.random() < percent then
				nextState[index] = mapper(person)
			end
		end
		return nextState
	end
end

return {
	Functions = {
		["mapped 50%"] = function(profiler)
			profiler.Begin("init")
			local src = atom(initialState)
			local out = mapped(src, mapper)
			out()
			profiler.End()

			profiler.Begin("update")
			src(updatePercentageOfPeople(0.5))
			profiler.End()
		end,

		["simple 50%"] = function(profiler)
			profiler.Begin("init")
			local src = atom(initialState)
			local out = simpleMapped(src)
			out()
			profiler.End()

			profiler.Begin("update")
			src(updatePercentageOfPeople(0.5))
			profiler.End()
		end,
	},
}
