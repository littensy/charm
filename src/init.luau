_G[script.modules.Promise] = _G[script]

local atom = require(script.atom)
local derive = require(script.derive)
local isAtom = require(script.isAtom)
local mapAtom = require(script.mapAtom)
local observe = require(script.observe)
local useAtom = require(script.react.useAtom)
local useAtomState = require(script.react.useAtomState)
local useSetAtom = require(script.react.useSetAtom)
local subscribe = require(script.subscribe)
local sync = require(script.sync)

export type Atom<State> = atom.Atom<State>
export type ReadonlyAtom<State> = atom.ReadonlyAtom<State>

return {
	atom = atom,
	derive = derive,
	isAtom = isAtom,
	observe = observe,
	mapAtom = mapAtom,
	subscribe = subscribe,
	sync = sync,
	useAtom = useAtom,
	useAtomState = useAtomState,
	useSetAtom = useSetAtom,
}
