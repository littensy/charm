type Update<T> = ((previous: T) -> T) | T
export type Atom<T> = (...Update<T>) -> T
export type Selector<T> = () -> T

return {}
