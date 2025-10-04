local core = require("./core")

local computed = core.computed
local setCurrentSub = core.setCurrentSub

type Mapped =
	& (<KI, VI, KO, VO>(getter: () -> { [KI]: VI }, mapper: (item: VI, key: KI) -> (VO, KO)) -> () -> { [KO]: VO })
	& (<K, VI, VO>(getter: () -> { [K]: VI }, mapper: (item: VI, key: K) -> VO) -> () -> { [K]: VO })

local function mapped<KI, VI, KO, VO>(getter: () -> { [KI]: VI }, mapper: (item: VI, key: KI) -> (VO, KO)): () -> { [KO]: VO }
	local currentData: { [KI]: VI } = {}
	local keyCache: { [KI]: KO } = {}

	local function map(value: VI, key: KI): (VO, KO)
		local currentSub = setCurrentSub(nil)
		local success, valueOut, keyOut = pcall(mapper, value, key)
		setCurrentSub(currentSub)

		if not success then
			error(`mapped() transform function failed: {valueOut}`)
		end

		return valueOut, if keyOut == nil then key else keyOut :: any
	end

	return computed(function(previousOutput)
		local currentOutput: { [KO]: VO } = previousOutput or {}
		local previousData = currentData
		currentData = getter()

		for key in previousData do
			if currentData[key] ~= nil then
				continue
			end

			local cachedKey = keyCache[key]

			if cachedKey then
				if currentOutput == previousOutput then
					currentOutput = table.clone(currentOutput)
				end
				currentOutput[cachedKey] = nil
				keyCache[key] = nil
			end
		end

		for key, value in currentData do
			if value == previousData[key] then
				continue
			end

			local valueOut, keyOut = map(value, key)

			if currentOutput[keyOut] ~= valueOut then
				if currentOutput == previousOutput then
					currentOutput = table.clone(currentOutput)
				end
				currentOutput[keyOut] = valueOut
				keyCache[key] = keyOut
			end
		end

		return currentOutput
	end)
end

--- Creates a new atom that is computed by mapping over the entries of an
--- existing atom. The returned atom is read-only, and its value is
--- automatically updated when the source atom changes.
---
--- @param getter A function that returns the table to map over.
--- @param mapper A function that transforms each value-key pair from the source into a new value or value-key pair for the resulting table.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#mappedgetter-mapper
local mapped = mapped :: Mapped

return mapped
