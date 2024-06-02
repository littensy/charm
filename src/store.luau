local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type WeakMap<K, V> = types.WeakMap<K, V>

local listeners: WeakMap<Atom<any>, WeakMap<() -> (), unknown>> = setmetatable({}, { __mode = "k" })

local captured: { [Atom<any>]: true } = {}
local capturing = false

local batched: { [() -> ()]: true } = {}
local batching = false

--[=[
	Returns whether the given value is an atom.

	@param value The value to check.
	@return `true` if the value is an atom, otherwise `false`.
]=]
local function isAtom(value: any)
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
		listener()
	end
end

--[=[
	Captures all atoms that are read during the function call and returns them
	along with the result of the function. Useful for tracking dependencies.
	
	@param molecule The function to run.
	@return A tuple containing the captured atoms and the result of the function.
]=]
local function capture<T>(callback: () -> T): ({ [Atom<any>]: true }, T)
	if listeners[callback] then
		return { [callback] = true }, callback()
	end

	capturing = true
	local result = callback()
	capturing = false

	local dependencies = table.clone(captured)
	table.clear(captured)

	return dependencies, result
end

--[=[
	Runs the given function and schedules listeners to be notified only once
	after the function has completed. Useful for batching multiple changes.
	
	@param callback The function to run.
]=]
local function batch(callback: () -> ())
	if batching then
		callback()
		return
	end

	batching = true
	callback()
	batching = false

	for listener in batched do
		listener()
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

	if not capturing then
		return callback(...)
	end

	capturing = false
	local result = callback(...)
	capturing = true

	return result
end

--[=[
	Sets whether the store is capturing atoms. If `true`, atoms that are read
	will be tracked and returned by `capture`.

	@param value Whether to capture atoms.
]=]
local function setCapturing(value: boolean)
	capturing = value
end

--[=[
	Returns whether the store is currently capturing atoms.

	@return `true` if the store is capturing atoms, otherwise `false`.
]=]
local function isCapturing()
	return capturing
end

return {
	listeners = listeners,
	captured = captured,
	isAtom = isAtom,
	notify = notify,
	capture = capture,
	batch = batch,
	peek = peek,
	setCapturing = setCapturing,
	isCapturing = isCapturing,
}
