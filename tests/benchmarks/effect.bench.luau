local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)

local computed = Charm.computed
local effect = Charm.effect
local atom = Charm.atom

local cleanup: () -> ()

return {
	AfterEach = function()
		cleanup()
	end,
	Functions = {
		atom = function()
			local state = atom(0)

			cleanup = effect(function()
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

			cleanup = effect(function()
				double()
			end)

			for _ = 1, 500 do
				state(math.random(1, 2))
			end
		end,
	},
}
