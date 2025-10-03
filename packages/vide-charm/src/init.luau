local Charm = require("./Charm")
local Vide = require("./Vide")

--- Returns a reactive source that updates when the given getter function's
--- value changes.
---
--- @param getter The atom or selector to subscribe to.
--- @return The reactive source.
local function useAtom<State>(getter: () -> State): () -> State
	local state = Vide.source(getter())

	Vide.cleanup(Charm.effect(function()
		Charm.untracked(state :: (State) -> State, getter())
	end))

	return state
end

return {
	useAtom = useAtom,
}
