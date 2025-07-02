local Charm = require("./Charm")
local React = require("./React")

local effect = Charm.effect
local useBinding = React.useBinding
local useEffect = React.useEffect
local useState = React.useState
local useMemo = React.useMemo

--- A hook that subscribes to changes in the given atom or selector. The
--- component is re-rendered whenever the state changes.
---
--- If the `dependencies` array is provided, the effect is re-created whenever
--- the dependencies change. Otherwise, the subscription is created once when
--- the component is mounted.
---
--- @param selector The atom or selector to subscribe to.
--- @param dependencies An array of values that the subscription depends on.
--- @return The current state.
local function useAtom<State>(selector: () -> State, dependencies: { any }?): State
	local state, setState = useState(selector)

	useEffect(function()
		return effect(function()
			setState(selector())
		end)
	end, dependencies or {})

	return state
end

--- A hook that subscribes to changes in the given atom or selector. Returns
--- a binding that updates when the state changes.
---
--- If the `dependencies` array is provided, the effect is re-created whenever
--- the dependencies change. Otherwise, the subscription is created once when
--- the component is mounted.
---
--- @param selector The atom or selector to subscribe to.
--- @param dependencies An array of values that the subscription depends on.
--- @return A binding that stores the current state.
local function useAtomBinding<State>(selector: () -> State, dependencies: { any }?)
	local initialState = useMemo(selector, {})
	local binding, setBinding = useBinding(initialState)

	useEffect(function()
		return effect(function()
			setBinding(selector())
		end)
	end, dependencies or {})

	return binding
end

return {
	useAtom = useAtom,
	useAtomBinding = useAtomBinding,
}
