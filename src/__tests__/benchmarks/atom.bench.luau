-- This file is for use by Benchmarker
-- https://boatbomber.itch.io/benchmarker

local Package = game:GetService("ReplicatedStorage").Packages.charm

local atom = require(Package.atom)
local derive = require(Package.derive)

local function parameterGenerator()
	return atom({ count = 0 })
end

local benchmarks = {
	atom = function(_, source: any)
		for _ = 1, 500 do
			source({ count = math.random(1, 2) })
		end
	end,

	derived = function(_, source: any)
		derive(function()
			return { count = 2 * source().count }
		end)
		for _ = 1, 500 do
			source({ count = math.random(1, 2) })
		end
	end,

	derived_nested = function(_, source: any)
		local double = derive(function()
			return { count = 2 * source().count }
		end)
		derive(function()
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
