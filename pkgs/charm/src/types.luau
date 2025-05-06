export type Selector<T = any> = () -> T

export type Atom<T = any> = ((((T) -> T) | T) -> T) & (() -> T)

return {}
