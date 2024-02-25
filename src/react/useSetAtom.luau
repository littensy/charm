local React = require(script.Parent.Parent.modules.React)

local atom = require(script.Parent.Parent.atom)
type Atom<T> = atom.Atom<T>

export type SetState<T> = (T | ((T) -> T)) -> ()

local function useSetAtom<State>(atom: Atom<State>): SetState<State>
	return React.useCallback(function(value)
		atom:set(value)
	end, { atom })
end

return useSetAtom
