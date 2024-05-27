_G[script.modules.Promise] = _G[script]

local atom = require(script.atom)
local computed = require(script.computed)
local effect = require(script.effect)
local mapped = require(script.mapped)
local observe = require(script.observe)
local peek = require(script.peek)
local useAtom = require(script.react.useAtom)
local store = require(script.store)
local subscribe = require(script.subscribe)
local sync = require(script.sync)
local types = require(script.types)

export type Atom<State> = types.Atom<State>
export type Molecule<State> = types.Molecule<State>
export type SyncPayload = types.SyncPayload

return {
	atom = atom,
	computed = computed,
	effect = effect,
	mapped = mapped,
	observe = observe,
	peek = peek,
	useAtom = useAtom,
	batch = store.batch,
	capture = store.capture,
	notify = store.notify,
	isAtom = store.isAtom,
	subscribe = subscribe,
	sync = sync,
}
