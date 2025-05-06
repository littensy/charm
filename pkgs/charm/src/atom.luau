local signals = require("./signals")
local types = require("./types")

type Atom<T> = types.Atom<T>

local signal = signals.signal

local function atomGetterSetterEquals<T>(
	source: () -> T,
	setSource: (((T) -> T) | T) -> T,
	equals: (T, T) -> boolean
): Atom<T>
	return function(...: ((T) -> T) | T): T
		if select("#", ...) == 0 then
			return source()
		end

		local nextState = (...)

		if type(nextState) == "function" then
			return setSource(function(currentState): T
				local nextState = nextState(currentState)
				return if equals(currentState, nextState) then currentState else nextState
			end)
		else
			return setSource(function(currentState): T
				return if equals(currentState, nextState) then currentState else nextState
			end)
		end
	end
end

local function atomGetterSetter<T>(source: () -> T, setSource: (((T) -> T) | T) -> T): Atom<T>
	return function(...: ((T) -> T) | T): T
		if select("#", ...) == 0 then
			return source()
		else
			return setSource((...))
		end
	end
end

local function atom<T>(state: T, equals: ((previous: T, current: T) -> boolean)?): Atom<T>
	local source, setSource = signal(state)

	if equals then
		return atomGetterSetterEquals(source, setSource, equals)
	else
		return atomGetterSetter(source, setSource)
	end
end

return atom
