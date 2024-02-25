local atom = require(script.Parent.Parent.atom)
type Atom<T> = atom.Atom<T>

local useAtomState = require(script.Parent.useAtomState)
local useSetAtom = require(script.Parent.useSetAtom)

type UseAtom =
	(<State>(atom: Atom<State>) -> (State, useSetAtom.SetState<State>))
	& (<State, Result>(
		atom: Atom<State>,
		selector: ((State) -> Result)?
	) -> (State | Result, useSetAtom.SetState<State | Result>))
	& (<State, Result>(atom: Atom<State>, selector: (State) -> Result) -> (Result, useSetAtom.SetState<State>))

local function useAtom<State>(atom: Atom<State>, selector: ((State) -> State)?): (State, useSetAtom.SetState<State>)
	return useAtomState(atom, selector), useSetAtom(atom)
end

return useAtom :: UseAtom
