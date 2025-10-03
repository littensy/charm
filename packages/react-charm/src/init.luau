local Charm = require("./Charm")
local React = require("./React")

--- A hook that subscribes to changes in the given atom or selector. The
--- component is re-rendered with the new state after an update.
---
--- If the `dependencies` array is provided, a new effect is created for the
--- current `getter` when the dependencies change. Otherwise, the effect is
--- created only once, when the component is mounted.
---
--- @param getter The atom or selector to watch.
--- @param dependencies An array of values used to memoize the getter.
--- @return The current state.
local function useAtom<T>(getter: () -> T, dependencies: { any }?): T
	local state, setState = React.useState(getter)

	React.useLayoutEffect(function()
		return Charm.effect(function()
			Charm.untracked(setState, getter())
		end)
	end, dependencies or {})

	return state
end

--- A hook that subscribes to changes in the given atom or selector. Returns
--- a binding that updates when the state changes.
---
--- If the `dependencies` array is provided, a new effect is created for the
--- current `getter` when the dependencies change. Otherwise, the effect is
--- created only once, when the component is mounted.
---
--- @param getter The atom or selector to watch.
--- @param dependencies An array of values used to memoize the getter.
--- @return A binding that stores the current state.
local function useAtomBinding<T>(getter: () -> T, dependencies: { any }?)
	local initialState = React.useMemo(getter, {})
	local binding, setBinding = React.useBinding(initialState)

	React.useLayoutEffect(function()
		return Charm.effect(function()
			Charm.untracked(setBinding, getter())
		end)
	end, dependencies or {})

	return binding
end

return {
	useAtom = useAtom,
	useAtomBinding = useAtomBinding,
}
