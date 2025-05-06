local Charm = require("@pkgs/charm/src/lib")

local atom = Charm.atom
local computed = Charm.computed
local effect = Charm.effect
local listen = Charm.listen

local signal = Charm.signals.signal
local computedSignal = Charm.signals.computed
local effectSignal = Charm.signals.effect

local w = 10
local h = 10

local function bench(name: string, test: () -> ())
	local start = os.clock()
	local iter = 0
	while os.clock() - start < 2 do
		iter += 1
		test()
	end
	local endTime = os.clock()
	local elapsed = endTime - start
	print(`{name}: {elapsed / iter * 1000 * 1000} us/iter`)
end

bench(`listen {w}*{h}`, function()
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
end)

bench(`effect {w}*{h}`, function()
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

bench(`signals {w}*{h}`, function()
	local src, setSrc = signal(1)
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
		end)
	end
	setSrc(src() + 1)
end)
