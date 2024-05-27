-- This file is for use by Benchmarker
-- https://boatbomber.itch.io/benchmarker

local Package = game:GetService("ReplicatedStorage").Packages.charm

local atom = require(Package.atom)
local computed = require(Package.computed)

local function parameterGenerator()
	return atom({ count = 0 })
end

local benchmarks = {
	atom = function(_, source: any)
		for _ = 1, 500 do
			source({ count = math.random(1, 2) })
		end
	end,

	computed = function(_, source: any)
		computed(function()
			return { count = 2 * source().count }
		end)
		for _ = 1, 500 do
			source({ count = math.random(1, 2) })
		end
	end,

	computed_nested = function(_, source: any)
		local double = computed(function()
			return { count = 2 * source().count }
		end)
		computed(function()
			return { count = 2 * double().count }
		end)
		for _ = 1, 500 do
			source({ count = math.random(1, 2) })
		end
	end,
}

return {
	ParameterGenerator = parameterGenerator,
	Functions = benchmarks,
}
