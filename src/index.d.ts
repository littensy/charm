export = Charm;
export as namespace Charm;

declare namespace Charm {
	interface Atom<T> extends ReadonlyAtom<T> {
		readonly __nominal: unique symbol;
		(state: T | ((state: T) => T)): T;
	}

	interface ReadonlyAtom<T> {
		(): T;
	}

	type AtomArrayToStates<Atoms extends ReadonlyAtom<any>[]> = {
		[Key in keyof Atoms]: Atoms[Key] extends ReadonlyAtom<infer State> ? State : never;
	};

	function atom<State>(state: State): Atom<State>;

	function isAtom(value: unknown): value is Atom<any>;

	function derive<State>(
		atom: ReadonlyAtom<State>,
		comparator?: (previous: State, current: State) => boolean,
	): ReadonlyAtom<State>;

	function subscribe<State>(
		atom: ReadonlyAtom<State>,
		callback: (state: State, previousState: State) => void,
	): () => void;

	function effect(callback: () => void): () => void;

	function observe<K, V>(
		atom: ReadonlyAtom<Map<K, V> | ReadonlyMap<K, V>>,
		factory: (value: V, key: K) => (() => void) | void,
	): () => void;

	function observe(atom: ReadonlyAtom<any>, factory: (value: unknown, key: unknown) => (() => void) | void): () => void;

	function mapAtom<V0, K1, V1>(
		atom: ReadonlyAtom<readonly V0[]> | ReadonlyAtom<V0[]>,
		mapper: (value: V0, index: number) => LuaTuple<[V1 | undefined, K1]>,
	): ReadonlyAtom<ReadonlyMap<K1, V1>>;

	function mapAtom<V0, V1>(
		atom: ReadonlyAtom<readonly V0[]> | ReadonlyAtom<V0[]>,
		mapper: (value: V0, index: number) => V1,
	): ReadonlyAtom<readonly V1[]>;

	function mapAtom<K0, V0, K1 = K0, V1 = V0>(
		atom: ReadonlyAtom<ReadonlyMap<K0, V0>> | ReadonlyAtom<Map<K0, V0>>,
		mapper: (value: V0, key: K0) => LuaTuple<[V1 | undefined, K1]> | V1,
	): ReadonlyAtom<ReadonlyMap<K1, V1>>;

	function mapAtom<K0 extends string | number | symbol, V0, K1, V1>(
		atom: ReadonlyAtom<{ readonly [K in K0]: V0 }>,
		mapper: (value: V0, key: K0) => LuaTuple<[V1 | undefined, K1]> | V1,
	): ReadonlyAtom<ReadonlyMap<K1, V1>>;

	function useAtomState<State>(atom: ReadonlyAtom<State>): State;

	function useAtomState<State, Result>(atom: ReadonlyAtom<State>, selector: (state: State) => Result): Result;

	function useSetAtom<State>(atom: ReadonlyAtom<State>): (state: State | ((previous: State) => State)) => void;

	function useAtom<State>(
		atom: ReadonlyAtom<State>,
	): LuaTuple<[state: State, setState: (state: State | ((previous: State) => State)) => void]>;

	function useAtom<State, Result>(
		atom: ReadonlyAtom<State>,
		selector: (state: State) => Result,
	): LuaTuple<[state: Result, setState: (state: Result | ((previous: Result) => Result)) => void]>;

	interface None {
		readonly __none: "__none";
	}

	type StatePatch<States> = {
		readonly [K in keyof States]?: (States[K] extends object ? StatePatch<States[K]> : States[K]) | None;
	};

	type SyncPayload<States> = { type: "set"; data: States } | { type: "patch"; data: StatePatch<States> };

	interface AtomMap {
		readonly [key: string]: Atom<any>;
	}

	type AtomMapToStates<Atoms extends AtomMap> = {
		readonly [Key in keyof Atoms]: Atoms[Key] extends Atom<infer State> ? State : never;
	};

	interface ClientSyncOptions<Atoms extends AtomMap> {
		atoms: Atoms;
	}

	interface ClientSyncer<States> {
		sync(payload: SyncPayload<States>): void;
	}

	interface ServerSyncOptions<Atoms extends AtomMap> {
		atoms: Atoms;
		interval?: number;
	}

	interface ServerSyncer<States> {
		onSync(callback: (player: Player, payload: SyncPayload<States>) => void): () => void;
		hydrate(player: Player): void;
	}

	namespace sync {
		function client<Atoms extends AtomMap>(options: ClientSyncOptions<Atoms>): ClientSyncer<AtomMapToStates<Atoms>>;

		function server<Atoms extends AtomMap>(options: ServerSyncOptions<Atoms>): ServerSyncer<AtomMapToStates<Atoms>>;
	}
}
