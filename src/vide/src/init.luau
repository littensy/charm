local Charm = require(script.Parent.Charm)
local Vide = if script.Parent:FindFirstChild("vide")
	then require(script.Parent.vide.src) :: never
	else require(script.Parent.Vide)

--[=[
	Subscribes to the state of an atom and returns a Vide source.
	
	@param callback The atom or selector to subscribe to.
	@return The reactive source.
]=]
local function useAtom<State>(callback: () -> State): State
	local state = Vide.source(callback())
	local unsubscribe = Charm.subscribe(callback, function(value)
		task.spawn(state, value)
	end)

	Vide.cleanup(unsubscribe)

	return state
end

return {
	useAtom = useAtom,
}
