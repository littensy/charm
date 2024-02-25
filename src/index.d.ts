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
		memo(equalityFn: (previous: State, current: State) => boolean): this;
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

	type AtomStates<T extends Atom<any>[]> = {
		[Key in keyof T]: T[Key] extends Atom<infer State> ? State : never;
	};

	function atom<State>(state: State): Atom<State>;

	function isAtom(value: unknown): value is Atom<any>;

	function derive<Atoms extends Atom<any>[], Result>(
		...args: [...atoms: Atoms, combiner: (...atoms: AtomStates<Atoms>) => Result]
	): ReadonlyAtom<Result>;

	function subscribe<State>(atom: Atom<State>, callback: (state: State) => void): () => void;

	function observe<K, V>(
		atom: Atom<Map<K, V> | ReadonlyMap<K, V>>,
		factory: (value: V, key: K) => (() => void) | void,
	): () => void;

	function observe(atom: Atom<any>, factory: (value: unknown, key: unknown) => (() => void) | void): () => void;

	function splitAtom<Item, Key, Id = Key>(
		listAtom: Atom<ReadonlyMap<Key, Item>> | Atom<Map<Key, Item>>,
		keyExtractor?: (item: Item) => Id,
	): Atom<ReadonlyMap<Id, Atom<Item>>>;

	function splitAtom<Item>(listAtom: Atom<readonly Item[]>): Atom<readonly Atom<Item>[]>;

	function splitAtom<Item, Id = number>(
		listAtom: Atom<readonly Item[]>,
		keyExtractor?: (item: Item) => Id,
	): Atom<ReadonlyMap<Id, Atom<Item>>>;

	function splitAtom<Item, Key extends string | number | symbol, Id = Key>(
		listAtom: Atom<{ readonly [K in Key]?: Item }>,
		keyExtractor?: (item: Item) => Id,
	): Atom<ReadonlyMap<Id, Atom<Item>>>;

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
}
