local Charm = require("@pkgs/charm/src/lib")
local bench = require("./bench")

local signals = Charm.signals

for _, w in { 10, 100 } do
	for _, h in { 10, 100 } do
		bench.run(`charm {w}*{h}`, function()
			local src = Charm.atom(1)
			for _ = 1, w do
				local last = src
				for _ = 1, h do
					local prev = last
					last = Charm.computed(function()
						return prev() + 1
					end)
				end
				Charm.effect(function()
					last()
				end)
			end
			src(src() + 1)
		end)

		bench.run(`alien-signals {w}*{h}`, function()
			local src, setSrc = signals.signal(1)
			for _ = 1, w do
				local last = src
				for _ = 1, h do
					local prev = last
					last = signals.computed(function()
						return prev() + 1
					end)
				end
				signals.effect(function()
					last()
				end)
			end
			setSrc(src() + 1)
		end)
	end
end
