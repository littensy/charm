local atom = require(script.Parent.atom)
local subscribe = require(script.Parent.subscribe)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type ReadonlyAtom<T> = types.ReadonlyAtom<T>

local function mapAtom<K0, V0, K1, V1>(itemsAtom: Atom<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1?)): ReadonlyAtom<{ [K1]: V1 }>
	local mappedAtom = atom({})
	local mappedAtomRef = setmetatable({ current = mappedAtom }, { __mode = "v" })
	local previousMappedItems: { [K1]: V1 } = {}
	local unsubscribe

	local function listener(items: { [K0]: V0 })
		if not mappedAtomRef.current then
			return unsubscribe()
		end

		local mappedItems = table.clone(mappedAtomRef.current())
		local mappedKeys = {}

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

		for key in previousMappedItems do
			if mappedKeys[key] == nil and mappedItems[key] == previousMappedItems[key] then
				mappedItems[key] = nil
			end
		end

		previousMappedItems = mappedItems
		mappedAtom(mappedItems)
	end

	unsubscribe = subscribe(itemsAtom, listener)
	listener(itemsAtom())

	return mappedAtom
end

return mapAtom
