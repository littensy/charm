export = Charm;
export as namespace Charm;

type Cleanup = () => void;

declare namespace Charm {
	/**
	 * A primitive state container that can be read from or written to. When
	 * the state changes, all subscribers are notified.
	 *
	 * @param state The next state or a function that produces the next state.
	 * @returns The current state.
	 */
	interface Atom<State> extends Selector<State> {
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
	 * A function that depends on one or more atoms and produces a value. Can be
	 * used to derive state from atoms.
	 *
	 * @deprecated Use `Selector<T>` instead.
	 * @returns The current state.
	 */
	type Molecule<State> = Selector<State>;

	/**
	 * Infers the type of the state produced by the given function.
	 */
	type StateOf<T> = T extends Selector<infer State> ? State : never;

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
	 * @param options Optional configuration.
	 * @returns A new read-only atom.
	 */
	function computed<State>(callback: Selector<State>, options?: AtomOptions<State>): Selector<State>;

	/**
	 * Subscribes to changes in the given atom or selector. The callback is
	 * called with the current state and the previous state immediately after a
	 * change occurs.
	 *
	 * @param callback The atom or selector to subscribe to.
	 * @param listener The function to call when the state changes.
	 * @returns A function that unsubscribes the callback.
	 */
	function subscribe<State>(callback: Selector<State>, listener: (state: State, prev: State) => void): Cleanup;

	/**
	 * Runs the given callback immediately and whenever any atom it depends on
	 * changes. Returns a cleanup function that unsubscribes the callback.
	 *
	 * @param callback The function to run.
	 * @returns A function that unsubscribes the callback.
	 */
	function effect(callback: () => Cleanup | void): Cleanup;

	/**
	 * Returns the result of the function without subscribing to changes. If a
	 * non-function value is provided, it is returned as is.
	 *
	 * @param callback The atom or selector to get the state of.
	 * @param args Arguments to pass to the function.
	 * @returns The current state.
	 */
	function peek<State, Args extends unknown[]>(callback: State | ((...args: Args) => State), ...args: Args): State;

	/**
	 * Returns whether the given value is an atom.
	 *
	 * @param value The value to check.
	 * @returns `true` if the value is an atom, otherwise `false`.
	 */
	function isAtom(value: unknown): value is Atom<any>;

	/**
	 * Runs the given function and schedules listeners to be notified only once
	 * after the function has completed. Useful for batching multiple changes.
	 *
	 * @param callback The function to run.
	 */
	function batch(callback: () => void): void;

	/**
	 * Captures all atoms that are read during the function call and returns them
	 * along with the result of the function. Useful for tracking dependencies.
	 *
	 * @param callback The function to run.
	 * @returns A tuple containing the captured atoms and the result of the function.
	 */
	function capture<State>(callback: Selector<State>): LuaTuple<[dependencies: Set<Atom<unknown>>, state: State]>;

	/**
	 * Notifies all subscribers of the given atom that the state has changed.
	 * Mainly for running effects, since subscriptions check for equality.
	 *
	 * @param atom The atom to notify.
	 */
	function notify<State>(atom: Atom<State>): void;

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
		callback: Selector<readonly Item[]>,
		factory: (item: Item, index: number) => Cleanup | void,
	): Cleanup;

	function observe<Key, Item>(
		callback: Selector<Map<Key, Item> | ReadonlyMap<Key, Item>>,
		factory: (item: Item, key: Key) => Cleanup | void,
	): Cleanup;

	function observe<Key extends string | number | symbol, Item>(
		callback: Selector<{ readonly [P in Key]: Item }>,
		factory: (item: Item, key: Key) => Cleanup | void,
	): Cleanup;

	/**
	 * Maps each entry in the atom's state to a new key-value pair. If the `mapper`
	 * function returns `undefined`, the entry is omitted from the resulting map.
	 * When the atom changes, the `mapper` is called for each entry in the state
	 * to compute the new state.
	 *
	 * @param callback The atom or selector to map.
	 * @param mapper The function that maps each entry.
	 * @returns A new atom with the mapped state.
	 */
	function mapped<V0, K1, V1>(
		callback: Selector<readonly V0[]>,
		mapper: (value: V0, index: number) => LuaTuple<[value: V1 | undefined, key: K1]>,
	): Selector<ReadonlyMap<K1, V1>>;

	function mapped<V0, V1>(
		callback: Selector<readonly V0[]>,
		mapper: (value: V0, index: number) => V1,
	): Selector<readonly V1[]>;

	function mapped<K0, V0, K1 = K0, V1 = V0>(
		callback: Selector<Map<K0, V0> | ReadonlyMap<K0, V0>>,
		mapper: (value: V0, key: K0) => LuaTuple<[value: V1 | undefined, key: K1]> | V1,
	): Selector<ReadonlyMap<K1, V1>>;

	function mapped<K0 extends string | number | symbol, V0, K1 = K0, V1 = V0>(
		callback: Selector<{ readonly [P in K0]: V0 }>,
		mapper: (value: V0, key: K0) => LuaTuple<[value: V1 | undefined, key: K1]> | V1,
	): Selector<ReadonlyMap<K1, V1>>;
}
