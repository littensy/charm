export type Atom<T> = (() -> T) & ((T | (T) -> T) -> T)
export type ReadonlyAtom<T> = () -> T
export type WeakMap<K, V> = typeof(setmetatable({} :: { [K]: V }, { __mode = "k" }))

return nil
