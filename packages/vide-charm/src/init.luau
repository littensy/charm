local Charm = require("./Charm")
local Vide = require("./Vide")

local subscribe = Charm.subscribe
local source = Vide.source
local cleanup = Vide.cleanup

--- Subscribes to the state of an atom or selector. Returns a source that
--- updates when the state changes.
---
--- @param callback The atom or selector to subscribe to.
--- @return The reactive source.
local function useAtom<State>(callback: () -> State): () -> State
	local state = source(callback())
	cleanup(subscribe(callback, state))
	return state
end

return {
	useAtom = useAtom,
}
