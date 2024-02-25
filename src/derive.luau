local atom = require(script.Parent.atom)
type Atom<T> = atom.Atom<T>
type ReadonlyAtom<T> = atom.ReadonlyAtom<T>

local reference = require(script.Parent.utils.reference)

type Derive =
	(<A, T>(Atom<A>, (A) -> T) -> ReadonlyAtom<T>)
	& (<A, B, T>(Atom<A>, Atom<B>, (A, B) -> T) -> ReadonlyAtom<T>)
	& (<A, B, C, T>(Atom<A>, Atom<B>, Atom<C>, (A, B, C) -> T) -> ReadonlyAtom<T>)
	& (<A, B, C, D, T>(Atom<A>, Atom<B>, Atom<C>, Atom<D>, (A, B, C, D) -> T) -> ReadonlyAtom<T>)
	& (<A, B, C, D, E, T>(Atom<A>, Atom<B>, Atom<C>, Atom<D>, Atom<E>, (A, B, C, D, E) -> T) -> ReadonlyAtom<T>)
	& (<T>(...(Atom<any> | ((...any) -> T))) -> ReadonlyAtom<T>)

local function derive<Result>(...): ReadonlyAtom<Result>
	local atoms: { Atom<unknown> } = { ... }
	local combiner: (...unknown) -> Result = table.remove(atoms) :: any
	local size = #atoms

	local dependencies: { unknown } = {}

	for index, atom in atoms do
		dependencies[index] = atom:get()
	end

	local derivedAtom = atom(combiner(table.unpack(dependencies, 1, size))):readonly()
	local getDerivedAtom = reference.weak(derivedAtom)

	for index, atom in atoms do
		local function listener(state: unknown)
			-- Remove the listener if the derived atom has been garbage collected,
			-- typically because no subscriptions to it exist.
			local derivedAtom = getDerivedAtom()

			if derivedAtom then
				dependencies[index] = state
				derivedAtom:setForced(combiner(table.unpack(dependencies, 1, size)))
			else
				atom.listeners[listener] = nil
			end
		end

		-- Tie the lifetime of the derived atom to the lifetime of its dependencies
		-- without creating a strong reference cycle. As long as an atom is in use,
		-- its derived atoms will be in use as well.
		derivedAtom.owners[atom] = true
		atom.listeners[listener] = true
	end

	return derivedAtom
end

return derive :: Derive
