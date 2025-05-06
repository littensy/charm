local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local computed = Charm.computed
local effect = Charm.effect
local atom = Charm.atom

return {
	Functions = {
		atom = function()
			local state = atom(0)

			effect(function()
				state()
			end)

			for _ = 1, 500 do
				state(math.random(1, 2))
			end
		end,

		computed = function()
			local state = atom(0)

			local double = computed(function()
				return 2 * state()
			end)

			effect(function()
				double()
			end)

			for _ = 1, 500 do
				state(math.random(1, 2))
			end
		end,
	},
}
