local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.charm)
local computed = Charm.computed
local atom = Charm.atom

return {
	ParameterGenerator = function() end,
	Functions = {
		atom = function()
			local state = atom(0)

			for _ = 1, 500 do
				state(math.random(1, 2))
			end
		end,

		computed = function()
			local state = atom(0)

			local _double = computed(function()
				return 2 * state()
			end)

			for _ = 1, 500 do
				state(math.random(1, 2))
			end
		end,
	},
}
