local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.DevPackages.Charm)
local signals = require(ReplicatedStorage.DevPackages.Charm.signals)

local function propagate(
	signal: <T>(T) -> (T?) -> T,
	computed: <T>(() -> T) -> () -> T,
	effect: (() -> ()) -> (),
	w: number,
	h: number
)
	local src = signal(1)
	for _ = 1, w do
		local last = src
		for _ = 1, h do
			local prev = last
			last = computed(function()
				return prev() + 1
			end)
		end
		effect(function()
			last()
		end)
	end
	src(src() + 1)
end

return {
	Functions = {
		charm = function()
			propagate(Charm.atom, Charm.computed, Charm.effect, 10, 10)
		end,
		alien_signals = function()
			propagate(signals.signal, signals.computed, signals.effect, 10, 10)
		end,
	},
}
