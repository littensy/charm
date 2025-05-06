local signals = require("./signals")

local computed = signals.computed
local effect = signals.effect
local getCurrentSub = signals.getCurrentSub
local onEffectCleanup = signals.onEffectCleanup
local onScopeDispose = signals.onScopeDispose

local function noop() end

local function observe<K, V>(selector: () -> { [K]: V }, observer: (item: V, key: K) -> ...() -> ()?): () -> ()
	local tracked = computed(function()
		return selector()
	end)

	local cleanups: { [K]: () -> () } = {}
	local currentItems: { [K]: V } = {}

	local function update(currentItems: { [K]: V }, previousItems: { [K]: V })
		for key in previousItems do
			local cleanup = cleanups[key]
			if currentItems[key] == nil and cleanup then
				cleanups[key] = nil
				cleanup()
			end
		end

		for key, value in currentItems do
			if previousItems[key] == nil then
				cleanups[key] = observer(value, key) or noop
			end
		end
	end

	local function teardown()
		for _, cleanup in cleanups do
			cleanup()
		end
		table.clear(cleanups)
	end

	local disposeEffect = effect(function()
		local previousItems = currentItems
		currentItems = tracked()
		update(currentItems, previousItems)
	end)

	if getCurrentSub() then
		onEffectCleanup(teardown)
	else
		onScopeDispose(teardown)
	end

	return function()
		disposeEffect()
		teardown()
	end
end

return observe
