local atom = require(script.Parent.atom)
local capture = require(script.Parent.capture)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>
type Source<T> = types.Source<T>

local function derive<T>(source: Source<T>, options: AtomOptions<T>?): Source<T>
	local atoms, state = capture(source)
	local derived = atom(state, options)
	local derivedRef = setmetatable({ current = derived }, { __mode = "v" })

	local function listener()
		if derivedRef.current then
			derivedRef.current(source())
		end
	end

	for atom in atoms do
		store.listeners[atom][listener] = derived
	end

	return derived
end

return derive
