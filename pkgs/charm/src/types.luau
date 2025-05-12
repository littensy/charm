export type Getter<T = any> = () -> T
export type Setter<T = any> = (update: Update<T>) -> T
export type Update<T = any> = T | (previous: T) -> T

export type Selector<T = any> = () -> T

export type Atom<T = any> = Setter<T> & Getter<T>

return {}
