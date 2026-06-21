local Charm = require("../packages/charm/src")
local bench = require("./bench")

local computed = Charm.computed
local effect = Charm.effect
local listen = Charm.listen
local signal = Charm.signal

for _, w in { 10, 100 } do
	for _, h in { 10, 100 } do
		bench.run(`propagate {w}*{h}`, function()
			local src, setSrc = signal(1)
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
			setSrc(src() + 1)
		end)
	end
end

for _, w in { 10, 100 } do
	for _, h in { 10, 100 } do
		bench.run(`propagate (listen) {w}*{h}`, function()
			local src, setSrc = signal(1)
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
			setSrc(src() + 1)
		end)
	end
end
