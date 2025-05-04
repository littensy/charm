local Charm = require(script.Parent.Charm)
local Vide = if script.Parent:FindFirstChild("vide")
	then require((script :: any).Parent.vide.src) :: never
	else require(script.Parent.Vide)

local subscribe = Charm.subscribe
local source = Vide.source
local cleanup = Vide.cleanup

--[=[
	Subscribes to the state of an atom and returns a Vide source.
	
	@param callback The atom or selector to subscribe to.
	@return The reactive source.
]=]
local function useAtom<State>(callback: () -> State): () -> State
	local state = source(callback())
	local dispose = subscribe(callback, state)
	cleanup(dispose)
	return state
end

return {
	useAtom = useAtom,
}
