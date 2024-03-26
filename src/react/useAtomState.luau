local requireReact = require(script.Parent.Parent.modules.React)
local subscribe = require(script.Parent.Parent.subscribe)

local types = require(script.Parent.Parent.types)
type Atom<T> = types.Atom<T>

type UseAtomState =
	(<State>(atom: Atom<State>) -> State)
	& (<State, Result>(atom: Atom<State>, ((State) -> Result)?) -> State | Result)
	& (<State, Result>(atom: Atom<State>, selector: (State) -> Result) -> Result)

local function useAtomState<State>(atom: Atom<State>, selector: ((State) -> State)?): State
	local React = requireReact()

	local state, setState = React.useState(function()
		return if selector then atom(selector) else atom()
	end)

	local latestSelector = React.useRef(selector)
	latestSelector.current = selector

	React.useEffect(function()
		return subscribe(atom, function(state)
			local selector = latestSelector.current
			setState(if selector then selector(state) else state)
		end)
	end, { atom })

	return state
end

return useAtomState :: UseAtomState
