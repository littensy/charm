local requireReact = require(script.Parent.Parent.modules.React)
local subscribe = require(script.Parent.Parent.subscribe)
local types = require(script.Parent.Parent.types)
type Molecule<T> = types.Molecule<T>

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
