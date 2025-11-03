local Charm = require("./Charm")
local React = require("./React")

--- Returns a React state that updates when the getter function updates.
--- Re-renders the component when the value changes.
---
--- If the `dependencies` array is provided, a new effect is created for the
--- current `getter` when the dependencies change. Otherwise, the effect is
--- created only once, when the component is mounted.
---
--- @param getter The signal or selector to watch.
--- @param dependencies An array of values used to memoize the getter.
--- @return The current state.
local function useSignalState<T>(getter: () -> T, dependencies: { any }?): T
	local value, setValue = React.useState(getter)

	React.useLayoutEffect(function()
		return Charm.effect(function()
			-- Wrap in untracked to avoid tracking inner effect and atom calls
			Charm.untracked(setValue, getter())
		end)
	end, dependencies or {})

	return value
end

--- Returns a React binding that updates when the getter function updates.
---
--- If the `dependencies` array is provided, a new effect is created for the
--- current `getter` when the dependencies change. Otherwise, the effect is
--- created only once, when the component is mounted.
---
--- @param getter The atom or selector to watch.
--- @param dependencies An array of values used to memoize the getter.
--- @return A binding that stores the current state.
local function useSignalBinding<T>(getter: () -> T, dependencies: { any }?)
	local initialValue = React.useMemo(getter, {})
	local binding, setBinding = React.useBinding(initialValue)

	React.useLayoutEffect(function()
		return Charm.effect(function()
			-- Wrap in untracked to avoid tracking inner effect and atom calls
			Charm.untracked(setBinding, getter())
		end)
	end, dependencies or {})

	return binding
end

return {
	useSignalState = useSignalState,
	useSignalBinding = useSignalBinding,
	useAtom = useSignalState,
}
