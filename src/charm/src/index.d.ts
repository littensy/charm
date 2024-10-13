export = Charm;
export as namespace Charm;

type Cleanup = () => void;

type AnyMap<K, V> =
	| Map<K, V>
	| ReadonlyMap<K, V>
	| (K extends string | number | symbol ? { readonly [Key in K]: V } : never);

declare namespace Charm {
	/**
	 * A primitive state container that can be read from and written to. When the
	 * state changes, all subscribers are notified.
	 *
	 * @template State The type of the state.
	 * @param state The next state or a function that produces the next state.
	 * @returns The current state, if no arguments are provided.
	 */
	interface Atom<State> extends Molecule<State> {
		/**
		 * @deprecated This property is not meant to be accessed directly.
		 */
		readonly __nominal: unique symbol;
		/**
		 * @param state The next state or a function that produces the next state.
		 * @returns The current state, if no arguments are provided.
		 */
		(state: State | ((prev: State) => State)): void;
	}

	/**
	 * A function that depends on one or more atoms and produces a state. Can be
	 * used to derive state from atoms.
	 *
	 * @returns The current state.
	 */
	type Molecule<State> = () => State;

	/**
	 * Infers the type of the state produced by the given molecule.
	 */
	type StateOf<T> = T extends Molecule<infer State> ? State : never;

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
	 * @template State The type of the state.
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
	 * the same molecule.
	 *
	 * @param molecule The function that produces the state.
	 * @param options Optional configuration.
	 * @returns A new read-only atom.
	 */
	function computed<State>(molecule: Molecule<State>, options?: AtomOptions<State>): Molecule<State>;

	/**
	 * Subscribes to changes in the given atom or molecule. The callback is
	 * called with the current state and the previous state immediately after a
	 * change occurs.
	 *
	 * @param molecule The atom or molecule to subscribe to.
	 * @param callback The function to call when the state changes.
	 * @returns A function that unsubscribes the callback.
	 */
	function subscribe<State>(molecule: Molecule<State>, callback: (state: State, prev: State) => void): Cleanup;

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
	 * @param molecule The atom or molecule to get the state of.
	 * @param args Arguments to pass to the molecule.
	 * @returns The current state.
	 */
	function peek<State, Args extends unknown[]>(molecule: State | ((...args: Args) => State), ...args: Args): State;

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
	 * @param molecule The function to run.
	 * @returns A tuple containing the captured atoms and the result of the function.
	 */
	function capture<State>(molecule: Molecule<State>): LuaTuple<[dependencies: Set<Atom<unknown>>, state: State]>;

	/**
	 * Notifies all subscribers of the given atom that the state has changed.
	 *
	 * @param atom The atom to notify.
	 */
	function notify<State>(atom: Atom<State>): void;

	/**
	 * Creates an instance of `factory` for each item in the atom's state, and
	 * cleans up the instance when the item is removed. Returns a cleanup function
	 * that unsubscribes all instances.
	 *
	 * @param molecule The atom or molecule to observe.
	 * @param factory The function that tracks the lifecycle of each item.
	 * @returns A function that unsubscribes all instances.
	 */
	function observe<Item>(
		molecule: Molecule<readonly Item[]>,
		factory: (item: Item, index: number) => Cleanup | void,
	): Cleanup;

	function observe<Key, Item>(
		molecule: Molecule<AnyMap<Key, Item>>,
		factory: (item: Item, key: Key) => Cleanup | void,
	): Cleanup;

	/**
	 * Maps each entry in the atom's state to a new key-value pair. If the `mapper`
	 * function returns `undefined`, the entry is omitted from the resulting map.
	 * When the atom changes, the `mapper` is called for each entry in the state
	 * to compute the new state.
	 *
	 * @param molecule The atom or molecule to map.
	 * @param mapper The function that maps each entry.
	 * @returns A new atom with the mapped state.
	 */
	function mapped<V0, K1, V1>(
		molecule: Molecule<readonly V0[]>,
		mapper: (value: V0, index: number) => LuaTuple<[value: V1 | undefined, key: K1]>,
	): Molecule<ReadonlyMap<K1, V1>>;

	function mapped<V0, V1>(
		molecule: Molecule<readonly V0[]>,
		mapper: (value: V0, index: number) => V1,
	): Molecule<readonly V1[]>;

	function mapped<K0, V0, K1 = K0, V1 = V0>(
		molecule: Molecule<AnyMap<K0, V0>>,
		mapper: (value: V0, key: K0) => LuaTuple<[value: V1 | undefined, key: K1]> | V1,
	): Molecule<ReadonlyMap<K1, V1>>;
}
