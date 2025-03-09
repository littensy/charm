local Charm = require(script.Parent.Parent.charm)
local React = if script.Parent.Parent:FindFirstChild("React")
	then require(script.Parent.Parent.React)
	else require((script.Parent.Parent :: any).react) :: never

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
local function useAtom<State>(callback: Charm.Selector<State>, dependencies: { any }?): State
	local state, setState = React.useState(callback)

	React.useEffect(function()
		setState(callback())
		return Charm.subscribe(callback, setState)
	end, dependencies or {})

	return state
end

return {
	useAtom = useAtom,
}
