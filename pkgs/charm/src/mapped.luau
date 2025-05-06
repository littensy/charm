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
		local output: { [KO]: VO } = previousOutput or {}
		local previousData = currentData
		currentData = selector()

		-- Check equality since the selector might not be a computed value
		if currentData == previousData then
			return output
		end

		-- Clear removed values from the output and key cache
		for key in previousData do
			if currentData[key] == nil then
				local keyOut = keyCache[key]

				if keyOut then
					output = ensureCanMutateOutput(output, previousOutput)
					output[keyOut] = nil
					keyCache[key] = nil
				end
			end
		end

		-- Process new or changed values
		for key, value in currentData do
			if value == previousData[key] then
				continue
			end

			local valueOut, keyOut = map(value, key)
			local cachedKeyOut = keyCache[key]

			if valueOut ~= nil then
				-- Skip update if the key and value are the same
				if keyOut == cachedKeyOut and valueOut == output[cachedKeyOut] then
					continue
				end

				output = ensureCanMutateOutput(output, previousOutput)
				output[keyOut] = valueOut
				keyCache[key] = keyOut

				-- Remove the old key if a new key is assigned
				if cachedKeyOut ~= nil and keyOut ~= cachedKeyOut then
					output[cachedKeyOut] = nil
				end
			elseif cachedKeyOut ~= nil then
				-- Remove the cached key if the new value is nil
				output = ensureCanMutateOutput(output, previousOutput)
				output[cachedKeyOut] = nil
				keyCache[key] = nil
			end
		end

		return output
	end)
end

return mapped :: Mapped
