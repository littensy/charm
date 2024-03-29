local atom = require(script.Parent.atom)
local capture = require(script.Parent.capture)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>
type Molecule<T> = types.Molecule<T>

local function derive<T>(molecule: Molecule<T>, options: AtomOptions<T>?): Molecule<T>
	local atoms, state = capture(molecule)
	local derived = atom(state, options)
	local derivedRef = setmetatable({ current = derived }, { __mode = "v" })

	local function listener()
		if derivedRef.current then
			derivedRef.current(molecule())
		end
	end

	for atom in atoms do
		store.listeners[atom][listener] = derived
	end

	return derived
end

return derive
