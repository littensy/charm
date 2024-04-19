local types = require(script.Parent.types)
type Atom<T> = types.Atom<T>
type WeakMap<K, V> = types.WeakMap<K, V>

local listeners: WeakMap<Atom<any>, WeakMap<() -> (), unknown>> = setmetatable({}, { __mode = "k" })
local captured: { [Atom<any>]: true } = {}
local batched: { [Atom<any>]: true } = {}
local capturing = false
local batching = false

local function setCapturing(value: boolean)
	capturing = value
end

local function isCapturing()
	return capturing
end

local function setBatching(value: boolean)
	batching = value
end

local function isBatching()
	return batching
end

return {
	listeners = listeners,
	captured = captured,
	batched = batched,
	setCapturing = setCapturing,
	isCapturing = isCapturing,
	setBatching = setBatching,
	isBatching = isBatching,
}
