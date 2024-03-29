local store = require(script.Parent.store)
local types = require(script.Parent.types)
local unwrap = require(script.Parent.unwrap)
type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>

local function atom<T>(state: T, options: AtomOptions<T>?): Atom<T>
	local equals = options and options.equals

	local function atom(...)
		if select("#", ...) == 0 then
			if store.shouldCapture() then
				store.captured[atom] = true
			end

			return state
		end

		local nextState = ...

		if type(nextState) == "function" then
			-- Atoms called in a function should not be included as dependencies
			nextState = unwrap(function()
				return nextState(state)
			end)
		end

		if state ~= nextState and not (equals and equals(state, nextState)) then
			state = nextState

			for listener in pairs(table.clone(store.listeners[atom])) do
				listener()
			end
		end

		return state
	end

	store.listeners[atom] = setmetatable({}, { __mode = "v" })

	return atom
end

return atom
