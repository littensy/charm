export type Set<T> = { [T]: true }

export type WeakMap<K, V> = typeof(setmetatable({} :: { [K]: V }, { __mode = "k" }))

--[=[
	A primitive state container that can be read from and written to. When the
	state changes, all subscribers are notified.

	@param state The next state or a function that produces the next state.
	@return The current state, if no arguments are provided.
]=]
export type Atom<T> = (state: (T | (T) -> T)?) -> T

--[=[
	A function that depends on one or more atoms and produces a state. Can be
	used to derive state from atoms.

	@template State The type of the state.
	@return The current state.
]=]
export type Selector<T> = () -> T

--[=[
	Optional configuration for creating an atom.
]=]
export type AtomOptions<T> = {
	--[=[
		A function that determines whether the state has changed. By default,
		a strict equality check (`===`) is used.
	]=]
	equals: (prev: T, next: T) -> boolean,
}

return nil
