local signals = require("./signals")
local types = require("./types")

type Atom<T> = types.Atom<T>
type Getter<T> = types.Getter<T>
type Setter<T> = types.Setter<T>
type Update<T> = types.Update<T>

local signal = signals.signal

type Equals<T> = (current: T, incoming: T) -> boolean

local function createAtom<T>(getter: Getter<T>, setter: Setter<T>): Atom<T>
	local function atom(...: Update<T>): T
		return if select("#", ...) == 0 then getter() else setter((...))
	end

	return atom
end

local function createAtomWithEqualityCheck<T>(getter: Getter<T>, setter: Setter<T>, equals: Equals<T>): Atom<T>
	local function atom(...: Update<T>): T
		if select("#", ...) == 0 then
			return getter()
		end

		local nextState = (...)

		return setter(function(currentState): T
			local nextState = if type(nextState) == "function" then nextState(currentState) else nextState
			return if equals(currentState, nextState) then currentState else nextState
		end)
	end

	return atom
end

local function atom<T>(state: T, equals: Equals<T>?): Atom<T>
	local getter, setter = signal(state)

	if not equals then
		return createAtom(getter, setter)
	else
		return createAtomWithEqualityCheck(getter, setter, equals)
	end
end

return atom
