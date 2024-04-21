local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type WeakMap<K, V> = types.WeakMap<K, V>

local listeners: WeakMap<Atom<any>, WeakMap<() -> (), unknown>> = setmetatable({}, { __mode = "k" })

local captured: { [Atom<any>]: true } = {}
local capturing = false

local batched: { [() -> ()]: true } = {}
local batching = false

local function isAtom(value: any)
	return not not (value and listeners[value])
end

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

local function batch(callback: () -> ())
	if batching then
		return callback()
	end

	batching = true
	callback()
	batching = false

	for listener in batched do
		listener()
	end

	table.clear(batched)
end

local function setCapturing(value: boolean)
	capturing = value
end

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
	setCapturing = setCapturing,
	isCapturing = isCapturing,
}
