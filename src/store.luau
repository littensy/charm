local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type WeakMap<K, V> = types.WeakMap<K, V>

local listeners: WeakMap<Atom<any>, WeakMap<() -> (), unknown>> = setmetatable({}, { __mode = "k" })

local capturing: { current: { [Atom<any>]: true }? } = {}
local batched: { [() -> ()]: true } = {}
local batching = false

--[=[
	Calls the given function and returns the result. If the function yields or
	throws an error, the thread is closed and an error is thrown. Regardless of
	the outcome, the `finally` function is called to clean up any resources.
	
	@param callback The function to run.
	@param finally Cleanup logic to run before error handling.
	@param ... Arguments to pass to the callback.
	@return The result of the callback.
]=]
local function try<T, U...>(callback: (U...) -> T | any, finally: (() -> ())?, ...: U...): T
	if _G.__DEV__ then
		local thread = coroutine.create(callback)
		local success, result = coroutine.resume(thread, ...)

		if finally then
			finally()
		end

		if coroutine.status(thread) == "suspended" then
			coroutine.close(thread)
			error("Yielding is not allowed in atom functions")
		elseif not success then
			error("An error occurred while running an atom function")
		end

		return result
	end

	local result = callback(...)

	if finally then
		finally()
	end

	return result
end

--[=[
	Returns whether the given value is an atom.

	@param value The value to check.
	@return `true` if the value is an atom, otherwise `false`.
]=]
local function isAtom(value: any): boolean
	return not not (value and listeners[value])
end

--[=[
	Notifies all subscribers of the given atom that the state has changed.
	
	@param atom The atom to notify.
]=]
local function notify(atom: Atom<any>)
	if batching then
		for listener in next, listeners[atom] do
			batched[listener] = true
		end
		return
	end

	for listener in next, table.clone(listeners[atom]) do
		try(listener)
	end
end

--[=[
	Captures all atoms that are read during the function call and returns them
	along with the result of the function. Useful for tracking dependencies.
	
	@param molecule The function to run.
	@return A tuple containing the captured atoms and the result of the function.
]=]
local function capture<T>(molecule: () -> T): ({ [Atom<any>]: true }, T)
	if listeners[molecule] then
		return { [molecule] = true }, molecule()
	end

	local dependencies = {}
	local previous = capturing.current

	capturing.current = dependencies

	local result = try(molecule, function()
		capturing.current = previous
	end)

	return dependencies, result
end

--[=[
	Runs the given function and schedules listeners to be notified only once
	after the function has completed. Useful for batching multiple changes.
	
	@param callback The function to run.
]=]
local function batch(callback: () -> ())
	if batching then
		return callback()
	end

	batching = true

	try(callback, function()
		batching = false
	end)

	for listener in batched do
		try(listener)
	end

	table.clear(batched)
end

--[=[
	Returns the result of the function without subscribing to changes. If a
	non-function value is provided, it is returned as is.
	
	@param molecule The atom or molecule to get the state of.
	@param args Arguments to pass to the molecule.
	@return The current state.
]=]
local function peek<T, U...>(callback: ((U...) -> T) | T, ...: U...): T
	if type(callback) ~= "function" then
		return callback
	end

	if not capturing.current then
		return callback(...)
	end

	local previous = capturing.current

	capturing.current = nil

	local result = try(callback, function()
		capturing.current = previous
	end, ...)

	return result
end

--[=[
	Subscribes the listener to the changes of the given atoms.
	
	@param dependencies The atoms to listen to.
	@param listener The function to call when the atoms change.
	@param ref Optionally bind the lifetime of the listener to a value.
]=]
local function connect(dependencies: { [Atom<any>]: true }, listener: () -> (), ref: unknown?)
	for atom in dependencies do
		listeners[atom][listener] = ref or true
	end
end

--[=[
	Unsubscribes the listener from the changes of the given atoms.
	
	@param dependencies The atoms to stop listening to.
	@param listener The function to stop calling when the atoms change.
]=]
local function disconnect(dependencies: { [Atom<any>]: true }, listener: () -> ())
	for atom in dependencies do
		listeners[atom][listener] = nil
	end
end

--[=[
	Disconnects the listener and evaluates the molecule again to capture any
	new dependencies. Useful for tracking conditional dependencies.

	@param molecule The atom or molecule to evaluate.
	@param dependencies The current dependencies.
	@param listener The listener to disconnect.
	@param ref Optionally bind the lifetime of the listener to a value.
	@return The new dependencies and the state of the molecule.
]=]
local function reconnect<T>(
	molecule: Atom<T>,
	dependencies: { [Atom<any>]: true },
	listener: () -> (),
	ref: unknown?
): ({ [Atom<any>]: true }, T)
	disconnect(dependencies, listener)
	local nextDependencies, state = capture(molecule)
	connect(nextDependencies, listener, ref)
	return nextDependencies, state
end

return {
	listeners = listeners,
	capturing = capturing,
	isAtom = isAtom,
	notify = notify,
	capture = capture,
	batch = batch,
	peek = peek,
	connect = connect,
	disconnect = disconnect,
	reconnect = reconnect,
}
