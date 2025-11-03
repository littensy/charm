local core = require("./core")

local computed = core.computed
local setActiveSub = core.setActiveSub

type Mapped =
	& (<KI, VI, KO, VO>(getter: () -> { [KI]: VI }, mapper: (item: VI, key: KI) -> (VO, KO)) -> () -> { [KO]: VO })
	& (<K, VI, VO>(getter: () -> { [K]: VI }, mapper: (item: VI, key: K) -> VO) -> () -> { [K]: VO })

local function mapped<KI, VI, KO, VO>(getter: () -> { [KI]: VI }, mapper: (item: VI, key: KI) -> (VO, KO)): () -> { [KO]: VO }
	local currentInput: { [KI]: VI } = {}
	local keyCache: { [KI]: KO } = {}

	local function map(value: VI, key: KI): (VO, KO)
		local prevSub = setActiveSub(nil)
		local success, valueOut, keyOut = pcall(mapper, value, key)
		setActiveSub(prevSub)

		if not success then
			error(`mapped() transform function failed: {valueOut}`)
		end

		return valueOut, if keyOut == nil then key else keyOut :: any
	end

	return computed(function(previousOutput)
		local currentOutput: { [KO]: VO } = previousOutput or {}
		local previousInput = currentInput
		currentInput = getter()

		for keyIn in previousInput do
			if currentInput[keyIn] ~= nil then
				continue
			end

			local prevKeyOut = keyCache[keyIn]

			if prevKeyOut then
				if currentOutput == previousOutput then
					currentOutput = table.clone(currentOutput)
				end
				currentOutput[prevKeyOut] = nil
				keyCache[keyIn] = nil
			end
		end

		for keyIn, valueIn in currentInput do
			if valueIn == previousInput[keyIn] then
				continue
			end

			local valueOut, keyOut = map(valueIn, keyIn)

			if currentOutput[keyOut] ~= valueOut then
				if currentOutput == previousOutput then
					currentOutput = table.clone(currentOutput)
				end
				currentOutput[keyOut] = valueOut
				keyCache[keyIn] = keyOut
			end
		end

		return currentOutput
	end)
end

--- Creates a new read-only signal that is computed by mapping over the entries
--- of an existing atom. If the key is omitted from the mapper's return value,
--- the original key is preserved.
---
--- @param getter Returns the table to map over.
--- @param mapper Transforms each value-key pair from the source into a new value or value-key pair for the resulting table.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#mappedgetter-mapper
local mapped = mapped :: Mapped

return mapped
