local atom = require(script.Parent.atom)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>
type Molecule<T> = types.Molecule<T>

--[=[
	Creates a read-only atom that derives its state from one or more atoms.
	Used to avoid unnecessary recomputations if multiple listeners depend on
	the same molecule.
	
	@param molecule The function that produces the state.
	@param options Optional configuration.
	@return A new read-only atom.
]=]
local function computed<T>(molecule: Molecule<T>, options: AtomOptions<T>?): Molecule<T>
	local dependencies, state = store.capture(molecule)
	local computedAtom = atom(state, options)
	local computedRef = setmetatable({ current = computedAtom }, { __mode = "v" })

	local function listener()
		if computedRef.current then
			dependencies, state = store.reconnect(molecule, dependencies, listener, computedRef.current)
			computedRef.current(state)
		end
	end

	store.connect(dependencies, listener, computedAtom)

	return computedAtom
end

return computed
