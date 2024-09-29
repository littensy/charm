local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>

--[=[
	Creates a new atom with the given state.
	
	@param state The initial state.
	@param options Optional configuration.
	@return A new atom.
]=]
local function atom<T>(state: T, options: AtomOptions<T>?): Atom<T>
	local equals = options and options.equals

	local function atom(...)
		if select("#", ...) == 0 then
			local index = store.capturing.index

			if index > 0 then
				store.capturing.stack[index][atom] = true
			end

			return state
		end

		local nextState = store.peek(..., state)

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
