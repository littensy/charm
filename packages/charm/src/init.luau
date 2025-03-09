local atom = require(script.atom)
local computed = require(script.computed)
local effect = require(script.effect)
local mapped = require(script.mapped)
local observe = require(script.observe)
local store = require(script.store)
local subscribe = require(script.subscribe)
local types = require(script.types)

export type Atom<State> = types.Atom<State>
export type Selector<State> = types.Selector<State>
export type Molecule<State> = types.Selector<State>

return {
	atom = atom,
	computed = computed,
	effect = effect,
	mapped = mapped,
	observe = observe,
	subscribe = subscribe,
	batch = store.batch,
	capture = store.capture,
	isAtom = store.isAtom,
	notify = store.notify,
	peek = store.peek,
}
