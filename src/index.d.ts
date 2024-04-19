export = Charm;
export as namespace Charm;

type Cleanup = () => void;

type AnyMap<K, V> =
	| Map<K, V>
	| ReadonlyMap<K, V>
	| (K extends string | number | symbol ? { readonly [Key in K]: V } : never);

declare namespace Charm {
	interface Atom<State> extends Molecule<State> {
		readonly __nominal: unique symbol;
		(state: State | ((prev: State) => State)): void;
	}

	type Molecule<State> = () => State;

	interface AtomOptions<State> {
		equals?: (prev: State, next: State) => boolean;
	}

	function atom<State>(state: State, options?: AtomOptions<State>): Atom<State>;

	function isAtom(value: unknown): value is Atom<any>;

	function derive<State>(molecule: Molecule<State>, options?: AtomOptions<State>): Molecule<State>;

	function subscribe<State>(molecule: Molecule<State>, callback: (state: State, prev: State) => void): Cleanup;

	function effect(callback: () => void): Cleanup;

	function unwrap<State, Args extends unknown[]>(molecule: State | ((...args: Args) => State), ...args: Args): State;

	function capture<State>(molecule: Molecule<State>): LuaTuple<[captured: Set<Atom<unknown>>, state: State]>;

	function batch(callback: () => void): void;

	function observe<Item>(
		molecule: Molecule<readonly Item[]>,
		factory: (item: Item, index: number) => Cleanup | void,
	): Cleanup;

	function observe<Key, Item>(
		molecule: Molecule<AnyMap<Key, Item>>,
		factory: (item: Item, key: Key) => Cleanup | void,
	): Cleanup;

	function map<V0, K1, V1>(
		molecule: Molecule<readonly V0[]>,
		mapper: (value: V0, index: number) => LuaTuple<[value: V1 | undefined, key: K1]>,
	): Molecule<ReadonlyMap<K1, V1>>;

	function map<V0, V1>(
		molecule: Molecule<readonly V0[]>,
		mapper: (value: V0, index: number) => V1,
	): Molecule<readonly V1[]>;

	function map<K0, V0, K1 = K0, V1 = V0>(
		molecule: Molecule<AnyMap<K0, V0>>,
		mapper: (value: V0, key: K0) => LuaTuple<[value: V1 | undefined, key: K1]> | V1,
	): Molecule<ReadonlyMap<K1, V1>>;

	// React

	function useAtomState<State>(molecule: Molecule<State>): State;

	function useAtomState<State, Result>(molecule: Molecule<State>, selector: (state: State) => Result): Result;

	function useSetAtom<State>(molecule: Molecule<State>): (state: State | ((prev: State) => State)) => void;

	function useAtom<State>(
		molecule: Molecule<State>,
	): LuaTuple<[state: State, setState: (state: State | ((prev: State) => State)) => void]>;

	function useAtom<State, Result>(
		molecule: Molecule<State>,
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
