_G[script.modules.Promise] = _G[script]

local atom = require(script.atom)
local capture = require(script.capture)
local derive = require(script.derive)
local effect = require(script.effect)
local isAtom = require(script.isAtom)
local map = require(script.map)
local observe = require(script.observe)
local useAtom = require(script.react.useAtom)
local useAtomState = require(script.react.useAtomState)
local useSetAtom = require(script.react.useSetAtom)
local subscribe = require(script.subscribe)
local sync = require(script.sync)
local types = require(script.types)
local unwrap = require(script.unwrap)

export type Atom<State> = types.Atom<State>
export type Source<State> = types.Source<State>
export type SyncPayload = types.SyncPayload

return {
	atom = atom,
	derive = derive,
	effect = effect,
	isAtom = isAtom,
	map = map,
	observe = observe,
	subscribe = subscribe,
	unwrap = unwrap,
	capture = capture,
	sync = sync,
	useAtom = useAtom,
	useAtomState = useAtomState,
	useSetAtom = useSetAtom,
}
