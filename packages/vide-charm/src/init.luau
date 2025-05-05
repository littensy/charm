local Charm = require(script.Parent.Charm)
local Vide = require(script.Parent.Vide)

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
	cleanup(subscribe(callback, state))
	return state
end

return {
	useAtom = useAtom,
}
