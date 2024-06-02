local requireReact = require(script.Parent.Parent.modules.React)
local subscribe = require(script.Parent.Parent.subscribe)
local types = require(script.Parent.Parent.types)
type Molecule<T> = types.Molecule<T>

--[=[
	A hook that subscribes to changes in the given atom or molecule. The
	component is re-rendered whenever the state changes.
	
	If the `dependencies` array is provided, the subscription to the atom or
	molecule is re-created whenever the dependencies change. Otherwise, the
	subscription is created once when the component is mounted.
	
	@param molecule The atom or molecule to subscribe to.
	@param dependencies An array of values that the subscription depends on.
	@return The current state.
]=]
local function useAtom<State>(molecule: Molecule<State>, dependencies: { any }?): State
	local React = requireReact()

	local state, setState = React.useState(molecule)

	React.useEffect(function()
		setState(molecule())
		return subscribe(molecule, setState)
	end, dependencies or {})

	return state
end

return useAtom
