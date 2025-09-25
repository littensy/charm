local Charm = require("./Charm")
local Vide = require("./Vide")

local subscribe = Charm.subscribe
local source = Vide.source
local cleanup = Vide.cleanup

--- Returns a reactive source that updates when the given getter function's
--- value changes.
---
--- @param getter The atom or selector to subscribe to.
--- @return The reactive source.
local function useAtom<State>(getter: () -> State): () -> State
	local state = source(getter())
	cleanup(subscribe(getter, state))
	return state
end

return {
	useAtom = useAtom,
}
