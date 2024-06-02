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
	 * @template State The type of the state.
	 * @returns The current state.
	 */
	type Molecule<State> = () => State;

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
	 * Note that dependencies are only evaluated once when the effect is created,
	 * so conditional dependencies may not work as expected.
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
	function capture<State>(molecule: Molecule<State>): LuaTuple<[captured: Set<Atom<unknown>>, state: State]>;

	/**
	 * Notifies all subscribers of the given atom that the state has changed.
	 *
	 * @param atom The atom to notify.
	 */
	function notify(atom: Atom<unknown>): void;

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

	// React

	/**
	 * A hook that subscribes to changes in the given atom or molecule. The
	 * component is re-rendered whenever the state changes.
	 *
	 * If the `dependencies` array is provided, the subscription to the atom or
	 * molecule is re-created whenever the dependencies change. Otherwise, the
	 * subscription is created once when the component is mounted.
	 *
	 * @param molecule The atom or molecule to subscribe to.
	 * @param dependencies An array of values that the subscription depends on.
	 * @returns The current state.
	 */
	function useAtom<State>(molecule: Molecule<State>, dependencies?: unknown[]): State;

	/**
	 * Synchronizes state between the client and server. The server sends patches
	 * to the client, which applies them to its local state.
	 */
	const sync: {
		/**
		 * Creates a `ClientSyncer` object that receives patches from the server and
		 * applies them to the local state.
		 *
		 * @param options The atoms to synchronize with the server.
		 * @returns A `ClientSyncer` object.
		 */
		client: <T extends Record<string, Atom<any>>>(options: ClientOptions<T>) => ClientSyncer<T>;
		/**
		 * Creates a `ServerSyncer` object that sends patches to the client and
		 * hydrates the client's state.
		 *
		 * @param options The atoms to synchronize with the client.
		 * @returns A `ServerSyncer` object.
		 */
		server: <T extends Record<string, Atom<any>>>(options: ServerOptions<T>) => ServerSyncer<T>;
	};

	/**
	 * A special value that denotes the absence of a value. Used to represent
	 * undefined values in patches.
	 */
	interface None {
		readonly __none: "__none";
	}

	type SyncPatch<T> = {
		readonly [P in keyof T]?: (T[P] extends object ? SyncPatch<T[P]> : T[P]) | (T[P] extends undefined ? None : never);
	};

	/**
	 * A payload that can be sent from the server to the client to synchronize
	 * state between the two.
	 */
	type SyncPayload<T> = { type: "init"; data: T } | { type: "patch"; data: SyncPatch<T> };

	interface ClientOptions<T extends Record<string, Atom<any>>> {
		/**
		 * The atoms to synchronize with the server.
		 */
		atoms: T;
	}

	interface ServerOptions<T extends Record<string, Atom<any>>> {
		/**
		 * The atoms to synchronize with the client.
		 */
		atoms: T;
		/**
		 * The interval at which to send patches to the client, in seconds.
		 * Defaults to `0` (patches are sent up to once per frame). Set to a
		 * negative value to disable automatic syncing.
		 */
		interval?: number;
	}

	interface ClientSyncer<T extends Record<string, Atom<any>>> {
		/**
		 * Applies a patch or initializes the state of the atoms with the given
		 * payload from the server.
		 *
		 * @param payload The patch or hydration payload to apply.
		 */
		sync(payload: SyncPayload<T>): void;
	}

	interface ServerSyncer<T extends Record<string, Atom<any>>> {
		/**
		 * Sets up a subscription to each atom that schedules a patch to be sent to
		 * the client whenever the state changes. When a change occurs, the `callback`
		 * is called with the player and the payload to send.
		 *
		 * Note that the `payload` object should not be mutated. If you need to
		 * modify the payload, apply the changes to a copy of the object.
		 *
		 * @param callback The function to call when the state changes.
		 * @returns A cleanup function that unsubscribes all listeners.
		 */
		connect(callback: (player: Player, payload: SyncPayload<T>) => void): Cleanup;
		/**
		 * Hydrates the client's state with the server's state. This should be
		 * called when a player joins the game and requires the server's state.
		 *
		 * @param player The player to hydrate.
		 */
		hydrate(player: Player): void;
	}
}
