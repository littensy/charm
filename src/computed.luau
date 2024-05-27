local atom = require(script.Parent.atom)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>
type Molecule<T> = types.Molecule<T>

local function computed<T>(molecule: Molecule<T>, options: AtomOptions<T>?): Molecule<T>
	local captured, state = store.capture(molecule)
	local computedAtom = atom(state, options)
	local computedRef = setmetatable({ current = computedAtom }, { __mode = "v" })

	local function listener()
		if computedRef.current then
			computedRef.current(molecule())
		end
	end

	for atom in captured do
		store.listeners[atom][listener] = computedAtom
	end

	return computedAtom
end

return computed
