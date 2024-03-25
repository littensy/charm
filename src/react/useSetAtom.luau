local requireReact = require(script.Parent.Parent.modules.React)

local types = require(script.Parent.Parent.types)
type Atom<T> = types.Atom<T>

export type SetState<T> = (T | ((T) -> T)) -> ()

local function useSetAtom<State>(atom: Atom<State>): SetState<State>
	return requireReact().useCallback(function(value)
		atom(value)
	end, { atom })
end

return useSetAtom
