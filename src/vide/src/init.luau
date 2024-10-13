local Charm = require(script.Parent.Charm)
local Vide = require(script.Parent.Vide)

--[=[
	Subscribes to the state of an atom and returns a Vide source.
	
	@param molecule The atom or molecule to subscribe to.
	@return The reactive source.
]=]
local function useAtom<State>(molecule: () -> State): State
	local state = Vide.source(molecule())
	local unsubscribe = Charm.subscribe(molecule, function(value)
		task.spawn(state, value)
	end)

	Vide.cleanup(unsubscribe)

	return state
end

return {
	useAtom = useAtom,
}
