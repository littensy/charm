local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type Set<T> = types.Set<T>
type WeakMap<K, V> = types.WeakMap<K, V>

local __DEV__ = _G.__DEV__

local listeners: WeakMap<Atom<any>, WeakMap<() -> (), unknown>> = setmetatable({}, { __mode = "k" })

local batched: Set<() -> ()> = {}
local batching = false

local capturing = {
	stack = {} :: { Set<Atom<any>> },
	index = 0,
}

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
	if __DEV__ then
		local thread = coroutine.create(callback)
		local success, result = coroutine.resume(thread, ...)

		if finally then
			finally()
		end

		if coroutine.status(thread) == "suspended" then
			local source, line, name = debug.info(callback, "sln")

			coroutine.close(thread)

			error(
				"Yielding is not allowed in atom functions. Consider wrapping this code in a Promise or task.defer instead."
					.. `\nFunction defined at: {source}:{line}`
					.. if name == "" then "" else ` function {name}`
			)
		elseif not success then
			local source, line, name = debug.info(callback, "sln")

			error(
				"An error occurred while running an atom function"
					.. `\nFunction defined at: {source}:{line}`
					.. (if name == "" then "" else ` function {name}`)
					.. `\nError: {result}`
			)
		end

		return result
	end

	if not finally then
		return callback(...)
	end

	local success, result = pcall(callback, ...)

	finally()
	assert(success, result)

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
	Returns the result of the function without subscribing to changes. If a
	non-function value is provided, it is returned as is.
	
	@param callback The atom or selector to get the state of.
	@param args Arguments to pass to the function.
	@return The current state.
]=]
local function peek<T, U...>(callback: ((U...) -> T) | T, ...: U...): T
	if type(callback) ~= "function" then
		return callback
	end

	if capturing.index == 0 then
		return callback(...)
	end

	capturing.index += 1
	capturing.stack[capturing.index] = {}

	local result = try(callback, function()
		capturing.stack[capturing.index] = nil
		capturing.index -= 1
	end, ...)

	return result
end

--[=[
	Captures all atoms that are read during the function call and returns them
	along with the result of the function. Useful for tracking dependencies.
	
	@param callback The function to run.
	@return A tuple containing the captured atoms and the result of the function.
]=]
local function capture<T, U...>(callback: (U...) -> T, ...: U...): (Set<Atom<any>>, T)
	-- If the callback is an atom, return it immediately
	if listeners[callback :: any] then
		return { [callback :: any] = true }, peek(callback)
	end

	local dependencies: Set<Atom<any>> = {}

	capturing.index += 1
	capturing.stack[capturing.index] = dependencies

	local result = try(callback, function()
		capturing.stack[capturing.index] = nil
		capturing.index -= 1
	end, ...)

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

	for listener in next, batched do
		try(listener)
	end

	table.clear(batched)
end

--[=[
	Subscribes the listener to the changes of the given atoms.
	
	@param atoms The atoms to listen to.
	@param listener The function to call when the atoms change.
	@param ref Optionally bind the lifetime of the listener to a value.
]=]
local function connect(atoms: Set<Atom<any>>, listener: () -> (), ref: unknown?)
	for atom in next, atoms do
		listeners[atom][listener] = ref or true
	end
end

--[=[
	Unsubscribes the listener from every atom it was connected to.
	
	@param atoms The atoms to stop listening to.
	@param listener The function to stop calling when the atoms change.
]=]
local function disconnect(atoms: Set<Atom<any>>, listener: () -> ())
	for atom in next, atoms do
		listeners[atom][listener] = nil
	end
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
}
