local atom = require(script.Parent.atom)
type Atom<T> = atom.Atom<T>
type ReadonlyAtom<T> = atom.ReadonlyAtom<T>

local reference = require(script.Parent.utils.reference)

type Split =
	(<Item, Key>(atom: Atom<{ [Key]: Item }>) -> ReadonlyAtom<{ [Key]: Atom<Item> }>)
	& (<Item, Key>(atom: Atom<{ [any]: Item }>, keyExtractor: (Item) -> Key) -> ReadonlyAtom<{ [Key]: Atom<Item> }>)

local function split<Item, Key>(
	itemsAtom: Atom<{ [Key]: Item }>,
	keyExtractor: ((Item) -> Key)?
): ReadonlyAtom<{ [Key]: Atom<Item> }>
	local splitAtom: ReadonlyAtom<{ [Key]: Atom<Item> }> = atom({}):readonly()
	local getSplitAtom = reference.weak(splitAtom)

	local previousAtoms: { [Key]: Atom<Item> } = {}
	local previousItems = itemsAtom:get()
	local listener: ({ [Key]: Item }) -> ()

	local function cleanup()
		itemsAtom.listeners[listener] = nil
		for _, atom in previousAtoms do
			atom:unmount()
		end
	end

	function listener(items)
		local splitAtom = getSplitAtom()

		if not splitAtom then
			return cleanup()
		end

		local atoms = table.clone(splitAtom:get())
		local itemsByKeys: { [Key]: Item } = {}

		for key, item in items do
			local id = if keyExtractor then keyExtractor(item) else key

			itemsByKeys[id] = item

			if atoms[id] then
				-- Force set the atom to avoid redundantly updating itemsAtom
				atoms[id]:setForced(item)
			else
				atoms[id] = atom(item):writable(function(update)
					local nextItems = table.clone(itemsAtom:get())
					nextItems[key] = update
					itemsAtom:set(nextItems)
				end)
			end
		end

		for key, item in previousItems do
			local id = if keyExtractor then keyExtractor(item) else key

			if itemsByKeys[id] == nil then
				atoms[id]:unmount()
				atoms[id] = nil
			end
		end

		previousAtoms, previousItems = atoms, items
		splitAtom:setForced(atoms)
	end

	itemsAtom.listeners[listener] = true
	listener(itemsAtom:get())

	return splitAtom
end

return (split :: any) :: Split
