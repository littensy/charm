local atom = require(script.Parent.atom)
local store = require(script.Parent.store)
local subscribe = require(script.Parent.subscribe)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type Selector<T> = types.Selector<T>

type Map =
	(<K0, V0, K1, V1>(fn: Selector<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1)) -> Selector<{ [K1]: V1 }>)
	& (<K0, V0, V1>(fn: Selector<{ [K0]: V0 }>, mapper: (V0, K0) -> V1?) -> Selector<{ [K0]: V1 }>)
	& (<K0, V0, K1, V1>(fn: Selector<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1?)) -> Selector<{ [K1]: V1 }>)

--[=[
	Maps each entry in the atom's state to a new key-value pair. If the `mapper`
	function returns `undefined`, the entry is omitted from the resulting map.
	When the atom changes, the `mapper` is called for each entry in the state
	to compute the new state.
	
	@param callback The atom or selector to map.
	@param mapper The function that maps each entry.
	@return A new atom with the mapped state.
]=]
local function mapped<K0, V0, K1, V1>(callback: Selector<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1?)): Selector<{ [K1]: V1 }>
	local mappedAtom = atom({})
	local mappedAtomRef = setmetatable({ current = mappedAtom }, { __mode = "v" })
	local prevMappedItems: { [K1]: V1 } = {}
	local prevKeyForItem: { [K0]: K1 } = {}
	local prevItems: { [K0]: V0 } = {}
	local unsubscribe

	local function listener(items: { [K0]: V0 })
		local mappedAtom = mappedAtomRef.current

		if not mappedAtom then
			return unsubscribe()
		end

		local hasChanges = false
		for key, item in next, items do
			if prevItems[key] ~= item or prevKeyForItem[key] == nil then
				hasChanges = true
				break
			end
		end
		if not hasChanges then
			for key in next, prevItems do
				if items[key] == nil then
					hasChanges = true
					break
				end
			end
		end
		if not hasChanges then
			return
		end

		local currentMapped = mappedAtom()
		local mappedItems: { [K1]: V1 } = currentMapped
		local mappedKeys = {}
		local newPrevKeyForItem: { [K0]: K1 } = {}
		local updatedPrevItems: { [K0]: V0 } = {}
		local changed = false

		local function ensureWritable()
			if mappedItems ~= currentMapped then
				return
			end

			local nextItems: { [K1]: V1 } = {}
			for key, value in next, currentMapped do
				nextItems[key] = value
			end
			mappedItems = nextItems
		end

		for key, item in next, items do
			local mappedKey: K1?
			local newItem: V1?
			local shouldReuseKey = prevItems[key] == item and prevKeyForItem[key] ~= nil

			if shouldReuseKey then
				mappedKey = prevKeyForItem[key]
				newItem = currentMapped[mappedKey :: K1]
			else
				local derivedItem, derivedKey = mapper(item, key)
				newItem = derivedItem
				if derivedKey == nil then
					derivedKey = key :: any
				end
				mappedKey = derivedKey :: K1
				if newItem == nil then
					if currentMapped[mappedKey :: K1] ~= nil then
						ensureWritable()
						mappedItems[mappedKey :: K1] = nil
						changed = true
					end
				else
					if currentMapped[mappedKey :: K1] ~= newItem then
						ensureWritable()
						mappedItems[mappedKey :: K1] = newItem :: V1
						changed = true
					end
				end
			end

			if mappedKey ~= nil and newItem ~= nil then
				local existingKey = mappedKeys[mappedKey]
				if existingKey ~= nil and existingKey ~= key then
					error("mapped(): mapper returned duplicate key")
				end
				mappedKeys[mappedKey] = key
				newPrevKeyForItem[key] = mappedKey
			end

			updatedPrevItems[key] = item
		end

		for key in next, prevMappedItems do
			if mappedKeys[key] == nil and currentMapped[key] == prevMappedItems[key] then
				ensureWritable()
				if mappedItems[key] ~= nil then
					mappedItems[key] = nil
					changed = true
				end
			end
		end

		prevKeyForItem = newPrevKeyForItem
		prevItems = updatedPrevItems
		prevMappedItems = mappedItems

		if changed then
			mappedAtom(mappedItems)
		end
	end

	unsubscribe = subscribe(callback, listener)

	store.peek(function(): ()
		listener(callback())
	end)

	return mappedAtom
end

return mapped :: Map
