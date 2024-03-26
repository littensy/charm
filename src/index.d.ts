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
		client(options: ClientOptions): ClientSyncer;
		server(options: ServerOptions): ServerSyncer;
	};

	interface SyncPatch {
		[key: string | number | symbol]: SyncPatch | { __none: "__none" } | string | number | boolean | undefined;
	}

	interface SyncPayload {
		type: "set" | "patch";
		data: SyncPatch;
	}

	interface ClientOptions {
		atoms: Record<string, Atom<any>>;
	}

	interface ServerOptions {
		atoms: Record<string, Atom<any>>;
		interval?: number;
	}

	interface ClientSyncer {
		sync(payload: SyncPayload): void;
	}

	interface ServerSyncer {
		connect(callback: (player: Player, payload: SyncPayload) => void): Cleanup;
		hydrate(player: Player): void;
	}
}
