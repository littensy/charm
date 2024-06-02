local atom = require(script.Parent.atom)
local effect = require(script.Parent.effect)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type Molecule<T> = types.Molecule<T>

type Map =
	(<K0, V0, K1, V1>(fn: Molecule<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1)) -> Molecule<{ [K1]: V1 }>)
	& (<K0, V0, V1>(fn: Molecule<{ [K0]: V0 }>, mapper: (V0, K0) -> V1?) -> Molecule<{ [K0]: V1 }>)
	& (<K0, V0, K1, V1>(fn: Molecule<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1?)) -> Molecule<{ [K1]: V1 }>)

--[=[
	Maps each entry in the atom's state to a new key-value pair. If the `mapper`
	function returns `undefined`, the entry is omitted from the resulting map.
	When the atom changes, the `mapper` is called for each entry in the state
	to compute the new state.
	
	@param molecule The atom or molecule to map.
	@param mapper The function that maps each entry.
	@return A new atom with the mapped state.
]=]
local function mapped<K0, V0, K1, V1>(molecule: Molecule<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1?)): Molecule<{ [K1]: V1 }>
	local mappedAtom = atom({})
	local mappedAtomRef = setmetatable({ current = mappedAtom }, { __mode = "v" })
	local prevMappedItems: { [K1]: V1 } = {}
	local unsubscribe

	unsubscribe = effect(function()
		if not mappedAtomRef.current then
			return unsubscribe()
		end

		local items = molecule()
		local mappedItems = table.clone(store.peek(mappedAtomRef.current))
		local mappedKeys = {}

		-- TODO: Only call mapper if the item has changed.
		for key, item in items do
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

		for key in prevMappedItems do
			if mappedKeys[key] == nil and mappedItems[key] == prevMappedItems[key] then
				mappedItems[key] = nil
			end
		end

		prevMappedItems = mappedItems
		mappedAtom(mappedItems)
	end)

	return mappedAtom
end

return mapped :: Map
