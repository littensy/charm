export = Charm;
export as namespace Charm;

type Cleanup = () => void;

type AnyMap<K, V> =
	| Map<K, V>
	| ReadonlyMap<K, V>
	| (K extends string | number | symbol ? { readonly [Key in K]: V } : never);

declare namespace Charm {
	interface Atom<T> extends Source<T> {
		readonly __nominal: unique symbol;
		(state: T | ((prev: T) => T)): void;
	}

	type Source<T> = () => T;

	interface AtomOptions<State> {
		equals?: (prev: State, next: State) => boolean;
	}

	function atom<State>(state: State, options?: AtomOptions<State>): Atom<State>;

	function isAtom(value: unknown): value is Atom<any>;

	function derive<State>(atom: Source<State>, options?: AtomOptions<State>): Source<State>;

	function subscribe<State>(atom: Source<State>, callback: (state: State, prev: State) => void): Cleanup;

	function effect(callback: Source<void>): Cleanup;

	function unwrap<State>(atom: State | Source<State>): State;

	function capture<State>(atom: Source<State>): LuaTuple<[captured: Set<Atom<unknown>>, state: State]>;

	function observe<Item>(
		atom: Source<readonly Item[]>,
		factory: (item: Item, index: number) => Cleanup | void,
	): Cleanup;

	function observe<Key, Item>(
		atom: Source<AnyMap<Key, Item>>,
		factory: (item: Item, key: Key) => Cleanup | void,
	): Cleanup;

	function map<V0, K1, V1>(
		atom: Source<readonly V0[]>,
		mapper: (value: V0, index: number) => LuaTuple<[value: V1 | undefined, key: K1]>,
	): Source<ReadonlyMap<K1, V1>>;

	function map<V0, V1>(atom: Source<readonly V0[]>, mapper: (value: V0, index: number) => V1): Source<readonly V1[]>;

	function map<K0, V0, K1 = K0, V1 = V0>(
		atom: Source<AnyMap<K0, V0>>,
		mapper: (value: V0, key: K0) => LuaTuple<[value: V1 | undefined, key: K1]> | V1,
	): Source<ReadonlyMap<K1, V1>>;

	// React

	function useAtomState<State>(atom: Source<State>): State;

	function useAtomState<State, Result>(atom: Source<State>, selector: (state: State) => Result): Result;

	function useSetAtom<State>(atom: Source<State>): (state: State | ((prev: State) => State)) => void;

	function useAtom<State>(
		atom: Source<State>,
	): LuaTuple<[state: State, setState: (state: State | ((prev: State) => State)) => void]>;

	function useAtom<State, Result>(
		atom: Source<State>,
		selector: (state: State) => Result,
	): LuaTuple<[state: Result, setState: (state: Result | ((prev: Result) => Result)) => void]>;

	// Sync

	const sync: {
		client: <T extends Record<string, Atom<any>>>(options: ClientOptions<T>) => ClientSyncer<T>;
		server: <T extends Record<string, Atom<any>>>(options: ServerOptions<T>) => ServerSyncer<T>;
		collect: (root: Instance) => Record<string, Atom<any>>;
	};

	interface None {
		__none: "__none";
	}

	type SyncPatch<T> = {
		readonly [P in keyof T]?: (T[P] extends object ? SyncPatch<T[P]> : T[P]) | (T[P] extends undefined ? None : never);
	};

	type SyncPayload<T> = { type: "init"; data: T } | { type: "patch"; data: SyncPatch<T> };

	interface ClientOptions<T extends Record<string, Atom<any>>> {
		atoms: T;
	}

	interface ServerOptions<T extends Record<string, Atom<any>>> {
		atoms: T;
		interval?: number;
	}

	interface ClientSyncer<T extends Record<string, Atom<any>>> {
		sync(payload: SyncPayload<T>): void;
	}

	interface ServerSyncer<T extends Record<string, Atom<any>>> {
		connect(callback: (player: Player, payload: SyncPayload<T>) => void): Cleanup;
		hydrate(player: Player): void;
	}
}
