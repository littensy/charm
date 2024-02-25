local React = require(script.Parent.Parent.modules.React)

local atom = require(script.Parent.Parent.atom)
type Atom<T> = atom.Atom<T>

type UseAtomState =
	(<State>(atom: Atom<State>) -> State)
	& (<State, Result>(atom: Atom<State>, ((State) -> Result)?) -> State | Result)
	& <State, Result>(atom: Atom<State>, selector: (State) -> Result) -> Result

local function useAtomState<State>(atom: Atom<State>, selector: ((State) -> State)?): State
	local state, setState = React.useState(function()
		return atom:get(selector :: (State) -> State)
	end)

	local latestSelector = React.useRef(selector)
	latestSelector.current = selector

	React.useEffect(function()
		local function listener(state: State)
			local selector = latestSelector.current
			setState(if selector then selector(state) else state)
		end

		atom.listeners[listener] = true

		return function()
			atom.listeners[listener] = nil
		end
	end, { atom })

	return state
end

return useAtomState :: UseAtomState
