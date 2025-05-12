local lib = require(script.lib)

export type Atom<T = any> = lib.Atom<T>
export type Getter<T = any> = lib.Getter<T>
export type Selector<T = any> = lib.Selector<T>
export type Setter<T = any> = lib.Setter<T>
export type Update<T = any> = lib.Update<T>

return lib
