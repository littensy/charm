local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>
local unwrap = require(script.Parent.unwrap)

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
		local nextState = unwrap(..., state)

		if state ~= nextState and not (equals and equals(state, nextState)) then
			state = nextState

			if store.isBatching() then
				store.batched[atom] = true
			else
				for listener in pairs(table.clone(store.listeners[atom])) do
					listener()
				end
			end
		end

		return state
	end

	store.listeners[atom] = setmetatable({}, { __mode = "v" })

	return atom
end

return atom
