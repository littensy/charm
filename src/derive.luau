local atom = require(script.Parent.atom)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type ReadonlyAtom<T> = types.ReadonlyAtom<T>

local function derive<T>(source: ReadonlyAtom<T>, comparator: ((old: T, new: T) -> boolean)?): ReadonlyAtom<T>
	local atoms, state = store.capture(source)
	local derived = atom(state)
	local derivedRef = setmetatable({ current = derived }, { __mode = "v" })

	local function listener()
		if not derivedRef.current then
			return
		end

		local nextState = source()

		if state ~= nextState and not (comparator and comparator(state, nextState)) then
			state = nextState
			derivedRef.current(nextState)
		end
	end

	for atom in atoms do
		store.listeners[atom][listener] = derived
	end

	return derived
end

return derive
