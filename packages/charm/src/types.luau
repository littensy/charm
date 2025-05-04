export type Selector<T = any> = () -> T

export type Atom<T = any> = ((((T) -> T) | T) -> T) & (() -> T)

export type AtomOptions<T = any> = {
	equals: ((prev: T, next: T) -> boolean)?,
}

return {}
