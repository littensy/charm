local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local computed = Charm.computed
local atom = Charm.atom

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
