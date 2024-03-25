local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type ReadonlyAtom<T> = types.ReadonlyAtom<T>
type WeakMap<K, V> = types.WeakMap<K, V>

local listeners: WeakMap<Atom<any>, WeakMap<() -> (), unknown>> = setmetatable({}, { __mode = "k" })
local captured: { [Atom<any>]: true } = {}
local capturing = false

local function capture<T>(source: ReadonlyAtom<T>): ({ [Atom<any>]: true }, T)
	if listeners[source] then
		return { [source] = true }, source()
	end

	capturing = true
	local success, result = pcall(source)
	capturing = false

	local dependencies = table.clone(captured)
	table.clear(captured)

	if not success then
		warn("An error occurred while calling an atom:", result)
	end

	return dependencies, result
end

local function shouldCapture()
	return capturing
end

return {
	listeners = listeners,
	captured = captured,
	capture = capture,
	shouldCapture = shouldCapture,
}
