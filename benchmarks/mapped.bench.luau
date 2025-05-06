--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local atom = Charm.atom
local computed = Charm.computed
local mapped = Charm.mapped
local pauseTracking = Charm.signals.pauseTracking
local resumeTracking = Charm.signals.resumeTracking

type Entry = { number }

local count = 512
local initialState: { Entry } = table.create(count)

for i = 1, count do
	initialState[i] = table.create(32, i)
end

local function mapper(value: Entry): Entry
	return table.clone(value)
end

local function simpleMapped(source: () -> { Entry }): () -> { Entry }
	return computed(function()
		local state = source()
		local nextState = {}

		for index, value in state do
			pauseTracking()
			local success, valueOut = pcall(mapper, value)
			resumeTracking()

			if success then
				nextState[index] = valueOut
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

local function test(
	percent: number,
	profiler: any,
	mapped: (src: () -> { Entry }, ...(Entry) -> Entry) -> () -> { Entry }
)
	local src = atom(initialState)
	local out = mapped(src, mapper)

	profiler.Begin("init")
	out()
	profiler.End()

	profiler.Begin("setup")
	src(updatePercentage(percent))
	profiler.End()

	profiler.Begin("update")
	out()
	profiler.End()
end

return {
	Functions = {
		["mapped 10%"] = function(profiler)
			test(0.1, profiler, mapped)
		end,
		["mapped 50%"] = function(profiler)
			test(0.5, profiler, mapped)
		end,
		["mapped 100%"] = function(profiler)
			test(1, profiler, mapped)
		end,
		["control 10%"] = function(profiler)
			test(0.1, profiler, simpleMapped)
		end,
		["control 50%"] = function(profiler)
			test(0.5, profiler, simpleMapped)
		end,
		["control 100%"] = function(profiler)
			test(1, profiler, simpleMapped)
		end,
	},
}
