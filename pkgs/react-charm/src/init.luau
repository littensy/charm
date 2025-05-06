local Charm = require(script.Parent.Charm)
local React = require(script.Parent.React)

local listen = Charm.listen
local useEffect = React.useEffect
local useState = React.useState

--[=[
	A hook that subscribes to changes in the given atom or selector. The
	component is re-rendered whenever the state changes.
	
	If the `dependencies` array is provided, the subscription to the atom or
	selector is re-created whenever the dependencies change. Otherwise, the
	subscription is created once when the component is mounted.
	
	@param callback The atom or selector to subscribe to.
	@param dependencies An array of values that the subscription depends on.
	@return The current state.
]=]
local function useAtom<State>(callback: () -> State, dependencies: { any }?): State
	local state, setState = useState(callback)

	useEffect(function()
		return listen(callback, setState)
	end, dependencies or {})

	return state
end

return {
	useAtom = useAtom,
}
