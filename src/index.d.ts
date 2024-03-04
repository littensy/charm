export = Charm;
export as namespace Charm;

declare namespace Charm {
	interface InternalAtom<State> {
		/** @hidden */
		readonly listeners: Set<(value: State) => void>;
		/** @hidden */
		readonly debugTraceback: string;
		/** @hidden */
		readonly debugLabel: string;
		/** @hidden */
		setForced(state: State | ((current: State) => State)): void;
	}

	interface BaseAtom<State> extends InternalAtom<State> {
		get(): State;
		get<Result>(selector: (state: State) => Result): Result;
		set(state: State | ((current: State) => State)): void;
		memo(areEqual: (previous: State, current: State) => boolean): this;
		writable(onSet?: (update: State, previous: State) => State | void): Atom<State>;
		readonly(): ReadonlyAtom<State>;
		named(label: string): this;
		unmount(): void;
	}

	interface Atom<State> extends BaseAtom<State> {
		(): State;
		(state: State | ((previous: State) => State)): void;
	}

	interface ReadonlyAtom<State> extends BaseAtom<State> {
		(): State;
		set: never;
	}

	type AtomArrayToStates<Atoms extends Atom<any>[]> = {
		[Key in keyof Atoms]: Atoms[Key] extends Atom<infer State> ? State : never;
	};

	function atom<State>(state: State): Atom<State>;

	function isAtom(value: unknown): value is Atom<any>;

	function derive<Atoms extends Atom<any>[], Result>(
		...args: [...atoms: Atoms, combiner: (...atoms: AtomArrayToStates<Atoms>) => Result]
	): ReadonlyAtom<Result>;

	function subscribe<State>(atom: Atom<State>, callback: (state: State) => void): () => void;

	function observe<K, V>(
		atom: Atom<Map<K, V> | ReadonlyMap<K, V>>,
		factory: (value: V, key: K) => (() => void) | void,
	): () => void;

	function observe(atom: Atom<any>, factory: (value: unknown, key: unknown) => (() => void) | void): () => void;

	function mapAtom<V0, K1, V1>(
		atom: Atom<readonly V0[]> | Atom<V0[]>,
		mapper: (value: V0, index: number) => LuaTuple<[V1 | undefined, K1]>,
	): ReadonlyAtom<ReadonlyMap<K1, V1>>;

	function mapAtom<V0, V1>(
		atom: Atom<readonly V0[]> | Atom<V0[]>,
		mapper: (value: V0, index: number) => V1,
	): ReadonlyAtom<readonly V1[]>;

	function mapAtom<K0, V0, K1 = K0, V1 = V0>(
		atom: Atom<ReadonlyMap<K0, V0>> | Atom<Map<K0, V0>>,
		mapper: (value: V0, key: K0) => LuaTuple<[V1 | undefined, K1]> | V1,
	): ReadonlyAtom<ReadonlyMap<K1, V1>>;

	function mapAtom<K0 extends string | number | symbol, V0, K1, V1>(
		atom: Atom<{ readonly [K in K0]: V0 }>,
		mapper: (value: V0, key: K0) => LuaTuple<[V1 | undefined, K1]> | V1,
	): ReadonlyAtom<ReadonlyMap<K1, V1>>;

	function useAtomState<State>(atom: Atom<State>): State;

	function useAtomState<State, Result>(atom: Atom<State>, selector: (state: State) => Result): Result;

	function useSetAtom<State>(atom: Atom<State>): (state: State | ((previous: State) => State)) => void;

	function useAtom<State>(
		atom: Atom<State>,
	): LuaTuple<[state: State, setState: (state: State | ((previous: State) => State)) => void]>;

	function useAtom<State, Result>(
		atom: Atom<State>,
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
