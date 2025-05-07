--!optimize 2

local signals = require("./signals")

local computed = signals.computed
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

type Mapped =
	& (<KI, VI, KO, VO>(selector: () -> { [KI]: VI }, mapper: (item: VI, key: KI) -> (VO, KO)) -> () -> { [KO]: VO })
	& (<K, VI, VO>(selector: () -> { [K]: VI }, mapper: (item: VI, key: K) -> VO) -> () -> { [K]: VO })

local function ensureCanMutateOutput<KO, VO>(output: { [KO]: VO }, previous: { [KO]: VO }?): { [KO]: VO }
	return if output == previous then table.clone(output) else output
end

local function mapped<KI, VI, KO, VO>(selector: () -> { [KI]: VI }, mapper: (item: VI, key: KI) -> (VO, KO)): () -> { [KO]: VO }
	local currentData: { [KI]: VI } = {}
	local keyCache: { [KI]: KO } = {}

	local function map(value: VI, key: KI): (VO, KO)
		pauseTracking()
		local success, valueOut, keyOut = pcall(mapper, value, key)
		resumeTracking()

		if not success then
			error(`mapped() transform function failed: {valueOut}`)
		end

		return valueOut, if keyOut ~= nil then keyOut else key :: any
	end

	return computed(function(previousOutput)
		local currentOutput: { [KO]: VO } = previousOutput or {}
		local previousData = currentData
		currentData = selector()

		for key, cachedKey in keyCache do
			if currentData[key] ~= nil then
				continue
			end

			currentOutput = ensureCanMutateOutput(currentOutput, previousOutput)
			currentOutput[cachedKey] = nil
			keyCache[key] = nil
		end

		for key, value in currentData do
			if value == previousData[key] then
				continue
			end

			local valueOut, keyOut = map(value, key)

			currentOutput = ensureCanMutateOutput(currentOutput, previousOutput)
			currentOutput[keyOut] = valueOut
			keyCache[key] = keyOut
		end

		return currentOutput
	end)
end

return mapped :: Mapped
