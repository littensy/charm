local Charm = require(script.Parent.Parent.charm)
local Vide = if script.Parent.Parent:FindFirstChild("Vide")
	then require(script.Parent.Parent.Vide)
	else require((script.Parent.Parent :: any).vide.src) :: never

--[=[
	Subscribes to the state of an atom and returns a Vide source.
	
	@param callback The atom or selector to subscribe to.
	@return The reactive source.
]=]
local function useAtom<State>(callback: () -> State): () -> State
	local state = Vide.source(callback())
	local unsubscribe = Charm.subscribe(callback, function(value)
		task.spawn(state :: (State) -> State, value)
	end)

	Vide.cleanup(unsubscribe)

	return state
end

return {
	useAtom = useAtom,
}
