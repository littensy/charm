export = Charm;
export as namespace Charm;

type Dispose = () => void;

declare namespace Charm {
	/**
	 * A primitive state container that can be read from or written to. When
	 * the state changes, all subscribers are notified.
	 *
	 * @param state The next state or a function that produces the next state.
	 * @returns The current state.
	 */
	interface Atom<State> {
		(): State;
		(nextState: State | ((prevState: State) => State)): State;
	}

	/**
	 * A function that depends on one or more atoms and produces a value. Can be
	 * used to derive state from atoms.
	 *
	 * @returns The current state.
	 */
	type Selector<State> = () => State;

	/**
	 * Infers the type of the state produced by the given function.
	 */
	type StateOf<T> = T extends () => infer State ? State : never;

	interface AtomOptions<State> {
		/**
		 * A function that determines whether the state has changed. By default,
		 * a strict equality check (`===`) is used.
		 */
		equals?: (prev: State, next: State) => boolean;
	}

	/**
	 * Creates a new atom with the given state.
	 *
	 * @param state The initial state.
	 * @param options Optional configuration.
	 * @returns A new atom.
	 */
	function atom<State>(state: State, options?: AtomOptions<State>): Atom<State>;

	// Overload for no arguments
	function atom<State>(state?: State, options?: AtomOptions<State>): Atom<State | undefined>;

	/**
	 * Creates a read-only atom that derives its state from one or more atoms.
	 * Used to avoid unnecessary recomputations if multiple listeners depend on
	 * the same atoms.
	 *
	 * @param callback The function that produces the state.
	 * @returns A new read-only atom.
	 */
	function computed<State>(callback: (prevResult?: State) => State): () => State;

	/**
	 * Subscribes to changes in the given atom or selector. The callback is
	 * called with the current state and the previous state only after a change
	 * occurs.
	 *
	 * @param callback The atom or selector to subscribe to.
	 * @param listener The function to call when the state changes.
	 * @returns A function that unsubscribes the callback.
	 */
	function subscribe<State>(callback: () => State, listener: (state: State, prevState: State) => void): Dispose;

	/**
	 * Subscribes to changes in the given atom or selector. The callback is
	 * called with the current state and the previous state immediately after
	 * subscribing, and again when a change occurs.
	 *
	 * @param callback The atom or selector to subscribe to.
	 * @param listener The function to call when the state changes.
	 * @returns A function that unsubscribes the callback.
	 */
	function listen<State>(
		callback: () => State,
		listener: (state: State, prevState: State, dispose: Dispose) => void,
	): Dispose;

	/**
	 * Runs the given callback immediately and whenever any atom it depends on
	 * changes. Returns a cleanup function that unsubscribes the callback.
	 *
	 * @param callback The function to run.
	 * @returns A function that unsubscribes the callback.
	 */
	function effect(callback: (dispose: Dispose) => Dispose | void): Dispose;

	/**
	 * Runs the given function and schedules listeners to be notified only once
	 * after the function has completed. Useful for batching multiple changes.
	 *
	 * @param callback The function to run.
	 */
	function batched(callback: () => void): void;

	/**
	 * Returns the result of the function without subscribing to changes.
	 *
	 * @param callback The atom or selector to get the state of.
	 * @param args Arguments to pass to the function.
	 * @returns The current state.
	 */
	function untracked<State, Args extends unknown[]>(callback: (...args: Args) => State, ...args: Args): State;

	/**
	 * Creates an instance of `factory` for each item in the atom's state, and
	 * cleans up the instance when the item is removed. Returns a cleanup function
	 * that unsubscribes all instances.
	 *
	 * @param callback The atom or selector to observe.
	 * @param factory The function that tracks the lifecycle of each item.
	 * @returns A function that unsubscribes all instances.
	 */
	function observe<Item>(
		callback: () => readonly Item[],
		factory: (item: Item, index: number) => Dispose | void,
	): Dispose;

	function observe<Key, Item>(
		callback: () => Map<Key, Item> | ReadonlyMap<Key, Item>,
		factory: (item: Item, key: Key) => Dispose | void,
	): Dispose;

	function observe<Key extends string | number | symbol, Item>(
		callback: () => { readonly [P in Key]: Item },
		factory: (item: Item, key: Key) => Dispose | void,
	): Dispose;

	/**
	 * Maps each entry in the atom's state to a new key-value pair. If the `mapper`
	 * function returns `undefined`, the entry is omitted from the resulting map.
	 * When the atom changes, the `mapper` only runs for the changed entries.
	 *
	 * @param callback The atom or selector to map.
	 * @param mapper The function that maps each entry.
	 * @returns A new atom with the mapped state.
	 */
	function mapped<V0, K1, V1>(
		callback: () => readonly V0[],
		mapper: (value: V0, index: number) => LuaTuple<[value: V1 | undefined, key: K1]>,
	): () => ReadonlyMap<K1, V1>;

	function mapped<V0, V1>(
		callback: () => readonly V0[],
		mapper: (value: V0, index: number) => V1,
	): () => readonly V1[];

	function mapped<K0, V0, K1 = K0, V1 = V0>(
		callback: () => Map<K0, V0> | ReadonlyMap<K0, V0>,
		mapper: (value: V0, key: K0) => LuaTuple<[value: V1 | undefined, key: K1]> | V1,
	): () => ReadonlyMap<K1, V1>;

	function mapped<K0 extends string | number | symbol, V0, K1 = K0, V1 = V0>(
		callback: () => { readonly [P in K0]: V0 },
		mapper: (value: V0, key: K0) => LuaTuple<[value: V1 | undefined, key: K1]> | V1,
	): () => ReadonlyMap<K1, V1>;
}
