local signals = require("./signals")
local types = require("./types")

type Atom<T> = types.Atom<T>
type AtomOptions<T> = types.AtomOptions<T>

local signal = signals.signal
local pauseTracking = signals.pauseTracking
local resumeTracking = signals.resumeTracking

local function atomOper<T>(source: (...T) -> T, equals: ((T, T) -> boolean)?, ...: ((T) -> T) | T): T
	if select("#", ...) == 0 then
		return source()
	end

	local transform = (...)
	local currentState = (source :: any).value
	local nextState: T

	-- If the transform is a function, call it with the current state and pause
	-- tracking to avoid adding signals called by the transform.
	if type(transform) == "function" then
		pauseTracking()
		local success, result = pcall(transform, currentState)
		resumeTracking()

		if not success then
			error(result, 2)
		end

		nextState = result
	else
		nextState = transform
	end

	if equals and equals(currentState, nextState) then
		return nextState
	end

	source(nextState)

	return nextState
end

local function atom<T>(state: T, options: AtomOptions<T>?): Atom<T>
	local source = signal(state)
	local equals = options and options.equals

	return function(...)
		return atomOper(source, equals, ...)
	end
end

return atom
