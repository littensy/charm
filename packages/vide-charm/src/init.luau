local Charm = require("./Charm")
local Vide = require("./Vide")

--[[
	Returns a reactive source that subscribes to the current value of the given
	signal or getter function.

	@param getter The getter function to subscribe to.
	@return The reactive source.
]]
local function useSignalState<State>(getter: () -> State): () -> State
	local state = Vide.source(getter())

	Vide.cleanup(Charm.listen(getter, state))

	return state
end

return {
	useSignalState = useSignalState,
	useAtom = useSignalState,
}
