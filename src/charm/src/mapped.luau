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
	local unsubscribe

	local function listener(items: { [K0]: V0 })
		local mappedAtom = mappedAtomRef.current

		if not mappedAtom then
			return unsubscribe()
		end

		local mappedItems = table.clone(mappedAtom())
		local mappedKeys = {}

		-- TODO: Only call mapper if the item has changed.
		for key, item in next, items do
			local newItem, newKey = mapper(item, key)
			if newKey == nil then
				newKey = key :: any
			end
			if mappedItems[newKey :: K1] ~= newItem then
				mappedItems[newKey :: K1] = newItem :: V1
			else
				mappedKeys[newKey] = key
			end
		end

		for key in next, prevMappedItems do
			if mappedKeys[key] == nil and mappedItems[key] == prevMappedItems[key] then
				mappedItems[key] = nil
			end
		end

		prevMappedItems = mappedItems
		mappedAtom(mappedItems)
	end

	unsubscribe = subscribe(callback, listener)

	store.peek(function(): ()
		listener(callback())
	end)

	return mappedAtom
end

return mapped :: Map
