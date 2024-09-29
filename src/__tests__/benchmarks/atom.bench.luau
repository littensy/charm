-- This file is for use by Benchmarker
-- https://boatbomber.itch.io/benchmarker

local Package = game:GetService("ReplicatedStorage").DevPackages.Charm

local atom = require(Package.atom)
local computed = require(Package.computed)

local function parameterGenerator()
	return atom(0)
end

local benchmarks = {
	atom = function(_, state: any)
		for _ = 1, 500 do
			state(math.random(1, 2))
		end
	end,

	computed = function(_, state: any)
		computed(function()
			return 2 * state()
		end)

		for _ = 1, 500 do
			state(math.random(1, 2))
		end
	end,
}

return {
	ParameterGenerator = parameterGenerator,
	Functions = benchmarks,
}
