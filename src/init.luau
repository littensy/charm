_G[script.modules.Promise] = _G[script]

local atom = require(script.atom)
local derive = require(script.derive)
local isAtom = require(script.isAtom)
local observe = require(script.observe)
local split = require(script.split)
local subscribe = require(script.subscribe)
local useAtom = require(script.react.useAtom)
local useAtomState = require(script.react.useAtomState)
local useSetAtom = require(script.react.useSetAtom)

export type Atom<State> = atom.Atom<State>
export type ReadonlyAtom<State> = atom.ReadonlyAtom<State>

return {
	atom = atom,
	derive = derive,
	isAtom = isAtom,
	observe = observe,
	split = split,
	subscribe = subscribe,
	useAtom = useAtom,
	useAtomState = useAtomState,
	useSetAtom = useSetAtom,
}
