local Charm = require("../charm")

local atom = Charm.atom
local computed = Charm.computed
local effect = Charm.effect

local signal = Charm.signals.signal
local computedSignal = Charm.signals.computed
local effectSignal = Charm.signals.effect

local w = 10
local h = 10

local function bench(name: string, test: () -> ())
	local start = os.clock()
	local iter = 0
	for _ = 1, 15000 do
		iter += 1
		test()
	end
	local endTime = os.clock()
	local elapsed = endTime - start
	print(`{name}: {elapsed / iter * 1000 * 1000} us/iter`)
end

bench(`charm {w} * {h}`, function()
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

bench(`alien-signals {w} * {h}`, function()
	local src = signal(1)
	for _ = 1, w do
		local last = src
		for _ = 1, h do
			local prev = last
			last = computedSignal(function()
				return prev() + 1
			end)
		end
		effectSignal(function()
			last()
			return nil
		end)
	end
	src(src() + 1)
end)
