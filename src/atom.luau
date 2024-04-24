local peek = require(script.Parent.peek)
local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>

local function atom<T>(state: T, options: AtomOptions<T>?): Atom<T>
	local equals = options and options.equals

	local function atom(...)
		if select("#", ...) == 0 then
			if store.isCapturing() then
				store.captured[atom] = true
			end

			return state
		end

		-- Atoms called in a function should not be a part of the dependency tree
		local nextState = peek(..., state)

		if state ~= nextState and not (equals and equals(state, nextState)) then
			state = nextState
			store.notify(atom)
		end

		return state
	end

	store.listeners[atom] = setmetatable({}, { __mode = "v" })

	return atom
end

return atom
