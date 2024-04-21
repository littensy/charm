_G[script.modules.Promise] = _G[script]

local atom = require(script.atom)
local derive = require(script.derive)
local effect = require(script.effect)
local map = require(script.map)
local observe = require(script.observe)
local useAtom = require(script.react.useAtom)
local useAtomState = require(script.react.useAtomState)
local useSetAtom = require(script.react.useSetAtom)
local store = require(script.store)
local subscribe = require(script.subscribe)
local sync = require(script.sync)
local types = require(script.types)
local unwrap = require(script.unwrap)

export type Atom<State> = types.Atom<State>
export type Molecule<State> = types.Molecule<State>
export type SyncPayload = types.SyncPayload

return {
	atom = atom,
	batch = store.batch,
	capture = store.capture,
	notify = store.notify,
	isAtom = store.isAtom,
	derive = derive,
	effect = effect,
	map = map,
	observe = observe,
	useAtom = useAtom,
	useAtomState = useAtomState,
	useSetAtom = useSetAtom,
	subscribe = subscribe,
	sync = sync,
	unwrap = unwrap,
}
