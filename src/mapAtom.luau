local atom = require(script.Parent.atom)
type Atom<T> = atom.Atom<T>
type ReadonlyAtom<T> = atom.ReadonlyAtom<T>
local reference = require(script.Parent.utils.reference)

local function mapAtom<K0, V0, K1, V1>(itemsAtom: Atom<{ [K0]: V0 }>, mapper: (V0, K0) -> (V1?, K1?)): ReadonlyAtom<{ [K1]: V1 }>
	local mappedAtom: ReadonlyAtom<{ [K1]: V1 }> = atom({}):readonly()
	local mappedAtomUnmount = mappedAtom.unmount
	local getMappedAtom = reference.weak(mappedAtom)
	local previousMappedItems: { [K1]: V1 } = {}

	local function listener(items)
		local mappedAtom = getMappedAtom()

		if not mappedAtom then
			itemsAtom.listeners[listener] = nil
			return
		end

		local mappedItems = table.clone(mappedAtom:get())
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
		mappedAtom:setForced(mappedItems)
	end

	function mappedAtom:unmount()
		mappedAtomUnmount(self)
		itemsAtom.listeners[listener] = nil
	end

	itemsAtom.listeners[listener] = true
	listener(itemsAtom:get())

	return mappedAtom
end

return mapAtom
