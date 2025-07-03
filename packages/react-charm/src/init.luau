local Charm = require("./Charm")
local React = require("./React")

local effect = Charm.effect
local useBinding = React.useBinding
local useEffect = React.useEffect
local useState = React.useState
local useMemo = React.useMemo

--- A hook that subscribes to changes in the given atom or selector. The
--- component is re-rendered with the new state after an update.
---
--- If the `dependencies` array is provided, a new effect is created for the
--- current `callback` when the dependencies change. Otherwise, the effect is
--- created only once, when the component is mounted.
---
--- @param callback The atom or selector to watch.
--- @param dependencies An array of values used to memoize the callback.
--- @return The current state.
local function useAtom<T>(callback: () -> T, dependencies: { any }?): T
	local state, setState = useState(callback)

	useEffect(function()
		return effect(function()
			setState(callback())
		end)
	end, dependencies or {})

	return state
end

--- A hook that subscribes to changes in the given atom or selector. Returns
--- a binding that updates when the state changes.
---
--- If the `dependencies` array is provided, a new effect is created for the
--- current `callback` when the dependencies change. Otherwise, the effect is
--- created only once, when the component is mounted.
---
--- @param callback The atom or selector to watch.
--- @param dependencies An array of values used to memoize the callback.
--- @return A binding that stores the current state.
local function useAtomBinding<T>(callback: () -> T, dependencies: { any }?)
	local initialState = useMemo(callback, {})
	local binding, setBinding = useBinding(initialState)

	useEffect(function()
		return effect(function()
			setBinding(callback())
		end)
	end, dependencies or {})

	return binding
end

return {
	useAtom = useAtom,
	useAtomBinding = useAtomBinding,
}
