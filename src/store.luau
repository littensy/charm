local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type WeakMap<K, V> = types.WeakMap<K, V>

local listeners: WeakMap<Atom<any>, WeakMap<() -> (), unknown>> = setmetatable({}, { __mode = "k" })
local captured: { [Atom<any>]: true } = {}
local capturing = false

local function setCapturing(value: boolean)
	capturing = value
end

local function shouldCapture()
	return capturing
end

return {
	listeners = listeners,
	captured = captured,
	setCapturing = setCapturing,
	shouldCapture = shouldCapture,
}
