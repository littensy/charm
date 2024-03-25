_G[script.modules.Promise] = _G[script]

local atom = require(script.atom)
local derive = require(script.derive)
local effect = require(script.effect)
local isAtom = require(script.isAtom)
local mapAtom = require(script.mapAtom)
local observe = require(script.observe)
local useAtom = require(script.react.useAtom)
local useAtomState = require(script.react.useAtomState)
local useSetAtom = require(script.react.useSetAtom)
local subscribe = require(script.subscribe)
local sync = require(script.sync)
local types = require(script.types)

export type Atom<State> = types.Atom<State>
export type ReadonlyAtom<State> = types.ReadonlyAtom<State>

return {
	atom = atom,
	derive = derive,
	effect = effect,
	isAtom = isAtom,
	mapAtom = mapAtom,
	observe = observe,
	subscribe = subscribe,
	sync = sync,
	useAtom = useAtom,
	useAtomState = useAtomState,
	useSetAtom = useSetAtom,
}
