local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

local atom = Charm.atom
local computed = Charm.computed
local effect = Charm.effect
local listen = Charm.listen

local function propagate(w: number, h: number)
	local src = atom(1)
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

local function propagateListen(w: number, h: number)
	local src = atom(1)
	for _ = 1, w do
		local last = src
		for _ = 1, h do
			local prev = last
			last = computed(function()
				return prev() + 1
			end)
		end
		listen(last, function() end)
	end
	src(src() + 1)
end

return {
	Functions = {
		["effect 1*100"] = function()
			propagate(1, 100)
		end,
		["effect 100*1"] = function()
			propagate(100, 1)
		end,
		["effect 10*10"] = function()
			propagate(10, 10)
		end,
		["listen 1*100"] = function()
			propagateListen(1, 100)
		end,
		["listen 100*1"] = function()
			propagateListen(100, 1)
		end,
		["listen 10*10"] = function()
			propagateListen(10, 10)
		end,
	},
}
