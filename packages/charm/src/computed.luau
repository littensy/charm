local atom = require(script.Parent.atom)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type AtomOptions<T> = types.AtomOptions<T>
type Selector<T> = types.Selector<T>

--[=[
	Creates a read-only atom that derives its state from one or more atoms.
	Used to avoid unnecessary recomputations if multiple listeners depend on
	the same atoms.

	@param callback The function that produces the state.
	@param options Optional configuration.
	@return A new read-only atom.
]=]
local function computed<T>(callback: Selector<T>, options: AtomOptions<T>?): Selector<T>
	local dependencies, state = store.capture(callback)
	local computedAtom = atom(state, options)
	local computedRef = setmetatable({ current = computedAtom }, { __mode = "v" })

	local pauseListening = false
	local function listener()
		if pauseListening then
			return
		end

		local computedAtom = computedRef.current

		if computedAtom then
			pauseListening = true
			dependencies, state = store.capture(callback)
			pauseListening = false
			computedAtom(state)
		end
	end

	store.connect(dependencies, listener, computedAtom)

	return computedAtom
end

return computed
