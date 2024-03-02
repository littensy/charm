-- This file is for use by Benchmarker
-- https://boatbomber.itch.io/benchmarker

local Package = game:GetService("ReplicatedStorage").Packages.charm

local atom = require(Package.atom)
local derive = require(Package.derive)

return {
	ParameterGenerator = function()
		return atom({ count = 0 })
	end,

	Functions = {
		atom = function(_, source: any)
			for _ = 1, 500 do
				source({ count = math.random(1, 2) })
			end
		end,

		derived = function(_, source: any)
			derive(source, function(state)
				return { count = 2 * state.count }
			end)
			for _ = 1, 500 do
				source({ count = math.random(1, 2) })
			end
		end,

		derived_memo = function(_, source: any)
			source:memo(function(previous, current)
				return previous.count == current.count
			end)
			derive(source, function(state)
				return { count = 2 * state.count }
			end)
			for _ = 1, 500 do
				source({ count = math.random(1, 2) })
			end
		end,

		derived_writable = function(_, source: any)
			local derived = derive(source, function(state)
				return { count = 2 * state.count }
			end):writable(function(update)
				source({ count = 0.5 * update.count })
			end)
			for _ = 1, 500 do
				derived({ count = 2 * math.random(1, 2) })
			end
		end,
	},
}
