export type WeakMap<K, V> = typeof(setmetatable({} :: { [K]: V }, { __mode = "k" }))

export type Atom<T> = (() -> T) & (state: T | (T) -> T) -> T

export type Molecule<T> = () -> T

export type AtomOptions<T> = {
	equals: (prev: T, next: T) -> boolean,
}

export type SyncPayload = {
	type: "patch" | "init",
	data: { [any]: any },
}

return nil
