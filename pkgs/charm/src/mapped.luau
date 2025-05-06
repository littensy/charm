local signals = require("./signals")

local computed = signals.computed
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

type MappedKey<VI, KO, VO> = {
	key: KO,
	value: VO,
}

local function mapped<KI, VI, KO, VO>(selector: () -> { [KI]: VI }, transform: (item: VI, key: KI) -> (VO, KO?)): () -> { [KO]: VO }
	local mappedKeys: { [KI]: MappedKey<VI, KO, VO> } = {}
	local previousItems: { [KI]: VI }?

	local function getTransform(value: VI, key: KI): (VO, KO?)
		pauseTracking()
		local success, valueOut, keyOut = pcall(transform, value, key)
		resumeTracking()

		if not success then
			error(`mapped() transform function failed: {valueOut}`)
		end

		return valueOut, keyOut
	end

	return computed(function(previousMappedItems)
		local currentItems = selector()

		-- If this is the initial run, create a map of the items and store the
		-- updated keys and values.
		if not previousItems or not previousMappedItems then
			local mappedItems: { [KO]: VO } = {}
			previousItems = currentItems

			for key, value in currentItems do
				local valueOut, keyOut = getTransform(value, key)
				local keyOut = if keyOut ~= nil then keyOut else key :: never

				if valueOut ~= nil then
					mappedKeys[key] = { key = keyOut, value = valueOut }
					mappedItems[keyOut] = valueOut
				end
			end

			return mappedItems
		end

		if previousItems == currentItems then
			return previousMappedItems
		end

		local mappedItems = table.clone(previousMappedItems)

		-- Update and remove mapped keys if the source values changed
		for key, oldValue in previousItems do
			local currentValue = currentItems[key]
			local mappedKey = mappedKeys[key]

			-- Remove the key if the source value changed from non-nil to nil
			if currentValue == nil then
				mappedKeys[key] = nil
				if mappedKey then
					mappedItems[mappedKey.key] = nil
				end
				continue
			end

			-- Do not call transform if the value has not changed
			if currentValue == oldValue then
				continue
			end

			local valueOut, keyOut = getTransform(currentValue, key)
			local keyOut = if keyOut ~= nil then keyOut else key :: never

			-- If there is no previous mappedKey, then this item was filtered
			-- out to optimize memory. We need to check if the value is nil to
			-- determine if we should add it back to the list.
			if not mappedKey then
				if valueOut ~= nil then
					mappedKeys[key] = { key = keyOut, value = valueOut }
					mappedItems[keyOut] = valueOut
				end
				continue
			end

			-- If the mapped value is nil, then delete mappedKey to save memory.
			-- This is treated the same as setting mappedKey.value to nil.
			if valueOut == nil then
				mappedKeys[key] = nil
				mappedItems[mappedKey.key] = nil
				continue
			end

			-- If the key changed since the last transform call, remove
			-- the old key and update mappedKey.
			if keyOut ~= mappedKey.key then
				mappedItems[mappedKey.key] = nil
				mappedKey.key = keyOut
			end

			mappedKey.value = valueOut
			mappedItems[keyOut] = valueOut
		end

		-- Add new keys if the value was not present in the previous state
		for key, currentValue in currentItems do
			local oldValue = previousItems[key]

			if oldValue ~= nil then
				continue
			end

			local valueOut, keyOut = getTransform(currentValue, key)
			local keyOut = if keyOut ~= nil then keyOut else key :: never

			if valueOut ~= nil then
				mappedKeys[key] = { key = keyOut, value = valueOut }
				mappedItems[keyOut] = valueOut
			end
		end

		previousItems = currentItems

		return mappedItems
	end)
end

return mapped
