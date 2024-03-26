local atom = require(script.Parent.atom)
local subscribe = require(script.Parent.subscribe)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type Source<T> = types.Source<T>

type Map =
	(<K0, V0, K1, V1>(atom: Source<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1)) -> Source<{ [K1]: V1 }>)
	& (<K0, V0, V1>(atom: Source<{ [K0]: V0 }>, mapper: (V0, K0) -> V1?) -> Source<{ [K0]: V1 }>)
	& (<K0, V0, K1, V1>(atom: Source<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1?)) -> Source<{ [K1]: V1 }>)

local function map<K0, V0, K1, V1>(itemsAtom: Source<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1?)): Source<{ [K1]: V1 }>
	local mappedAtom = atom({})
	local mappedAtomRef = setmetatable({ current = mappedAtom }, { __mode = "v" })
	local prevMappedItems: { [K1]: V1 } = {}
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

		for key in prevMappedItems do
			if mappedKeys[key] == nil and mappedItems[key] == prevMappedItems[key] then
				mappedItems[key] = nil
			end
		end

		prevMappedItems = mappedItems
		mappedAtom(mappedItems)
	end

	unsubscribe = subscribe(itemsAtom, listener)
	listener(itemsAtom())

	return mappedAtom
end

return map :: Map
