type Key = string | number | symbol;
type Cleanup = () => void;

export interface Atom<T> {
	(): T;
	(value: T | ((value: T) => T)): T;
}

export type Selector<T> = () => T;

export type Equals<T> = (current: T, incoming: T) => boolean;

export const flags: {
	strict: boolean;
};

export function atom<T>(value: T, equals?: Equals<T>): Atom<T>;
// Overload for undefined initial value
export function atom<T>(): Atom<T | undefined>;

export function computed<T>(getter: (previousValue?: T) => T, equals?: Equals<T>): () => T;

export function effect(callback: () => Cleanup | void): Cleanup;

export function effectScope(callback: () => Cleanup | void, detached?: boolean): Cleanup;

export function listen<T>(
	callback: () => T,
	listener: (value: T, previousValue: T | undefined, dispose: Cleanup) => void,
): Cleanup;

export function subscribe<T>(callback: () => T, listener: (value: T, previousValue: T) => void): Cleanup;

export function mapped<VI, KI, VO, KO = KI>(
	callback: () => Map<KI, VI> | ReadonlyMap<KI, VI>,
	mapper: (value: VI, key: KI) => LuaTuple<[VO, KO]> | VO,
): () => ReadonlyMap<KO, VO>;
// Overload for arrays
export function mapped<VI, VO, K extends Key = number>(
	callback: () => readonly VI[],
	mapper: (value: VI, key: number) => LuaTuple<[VO, K]> | VO,
): () => K extends number ? readonly VO[] : { readonly [P in K]: VO };
// Overload for objects
export function mapped<VI, KI extends Key, VO, KO extends Key = KI>(
	callback: () => { readonly [K in KI]: VI },
	mapper: (value: VI, key: KI) => LuaTuple<[VO, KO]> | VO,
): () => { readonly [K in KO]: VO };

export function observe<V, K = number>(
	callback: () => Map<K, V> | ReadonlyMap<K, V> | readonly V[],
	observer: (value: V, key: K) => Cleanup | void,
): Cleanup;
// Overload for objects
export function observe<V, K extends Key>(
	callback: () => { readonly [K in Key]: V },
	observer: (value: V, key: K) => Cleanup | void,
): Cleanup;

export function onCleanup(callback: Cleanup, failSilently?: boolean): void;

export function batched<Args extends any[], Result>(
	callback: (...args: Args) => Result,
	...args: Args
): (...args: Args) => Result;

export function peek<Args extends any[], Result>(callback: (...args: Args) => Result, ...args: Args): Result;

export function untracked<Args extends any[], Result>(callback: (...args: Args) => Result, ...args: Args): Result;
