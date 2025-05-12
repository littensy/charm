local Charm = require(script.Parent.Charm)
local Vide = require(script.Parent.Vide)

local subscribe = Charm.subscribe
local source = Vide.source
local cleanup = Vide.cleanup

--- Subscribes to the state of an atom or selector. Returns a source that
--- updates when the state changes.
---
--- @param selector The atom or selector to subscribe to.
--- @return The reactive source.
local function useAtom<State>(selector: () -> State): () -> State
	local state = source(selector())
	cleanup(subscribe(selector, state))
	return state
end

return {
	useAtom = useAtom,
}
