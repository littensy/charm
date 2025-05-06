local Charm = require("@pkgs/charm/src/lib")
local bench = require("./bench")

local atom = Charm.atom
local computed = Charm.computed
local effect = Charm.effect

for _, w in { 1, 10, 100 } do
	for _, h in { 1, 10, 100 } do
		bench.run(`propagate {w}*{h}`, function()
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
		end)
	end
end
