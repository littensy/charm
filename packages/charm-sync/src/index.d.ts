import { Atom, Getter, Setter } from "@rbxts/charm";

type Key = string | number | symbol;

/**
 * Represents the removal of a value from the state.
 */
export interface None {
	readonly __none: "__none";
}

export type MaybeNone<T> = undefined extends T ? None : never;

type GetterMap = Record<string, Getter<any>>;
type SetterMap = Record<string, Setter<any>>;

/**
 * Infers the type of the return values produced by a map of functions.
 */
export type StateOfMap<T> = {
	readonly [P in keyof T]: T[P] extends () => infer State ? State : never;
};

type DataTypes = {
	[P in keyof CheckableTypes as P extends keyof CheckablePrimitives ? never : P]: CheckableTypes[P];
};

type DataType = DataTypes[keyof DataTypes];

/**
 * A partial patch that can be applied to the state to update it. Represents
 * the difference between the current state and the next state.
 *
 * If a value was removed, it is replaced with `None`. This can be checked
 * using the `isNone` function.
 */
// TODO: Optimize type, this looks overly complex
export type SyncPatch<State, FixArrays extends boolean = true> = MaybeNone<State> | State extends
	| ReadonlyMap<infer K, infer V>
	| Map<infer K, infer V>
	? ReadonlyMap<K, SyncPatch<V, FixArrays> | None>
	: State extends Set<infer T> | ReadonlySet<infer T>
		? ReadonlyMap<T, true | None>
		: State extends readonly (infer T)[]
			? FixArrays extends true
				? ReadonlyMap<string | number, SyncPatch<T, FixArrays> | None>
				: readonly (SyncPatch<T, FixArrays> | None | undefined)[]
			: State extends DataType
				? State
				: State extends object
					? { readonly [P in keyof State]?: SyncPatch<State[P], FixArrays> }
					: State;

/**
 * A payload that can be sent from the server to the client to synchronize
 * state between the two.
 */
export type SyncPayload<Getters extends GetterMap = GetterMap, FixArrays extends boolean = true> =
	| { type: "init"; data: StateOfMap<Getters> }
	| { type: "patch"; data: SyncPatch<StateOfMap<Getters>, FixArrays> };

/**
 * Global configuration options that affect the behavior of Charm Sync.
 */
export const config: {
	/**
	 * The interval at which to send patches to the client, in seconds.
	 * Defaults to `0` (patches are sent up to once per frame). Set to a
	 * negative value to disable automatic syncing.
	 *
	 * @server
	 */
	interval: number;
	/**
	 * Whether the history of state changes since the client's last update
	 * should be preserved. This is useful for values that change multiple
	 * times per frame, where each individual change is important. Defaults
	 * to `false`.
	 *
	 * @server
	 */
	preserveHistory: boolean;
	/**
	 * When `true`, Charm will apply validation and serialize unsafe arrays
	 * to address remote event argument limitations. Defaults to `true`.
	 * This option should be disabled if your network library uses a custom
	 * serialization method (i.e. Zap, ByteNet) to prevent interference.
	 *
	 * @server
	 */
	fixArrays: boolean;
	/**
	 * When `true`, synced state containing unsafe sparse arrays or mixed
	 * tables will throw an error. Only checked in strict mode and if
	 * `fixArrays` is enabled. Defaults to `true`.
	 *
	 * @server
	 */
	validatePatches: boolean;
};

/**
 * @client
 */
export namespace client {
	/**
	 * Registers a map of setters to the state with the corresponding keys on the
	 * server. When the server sends updates, these setters will be called with
	 * the new values.
	 *
	 * Atoms, signals converted to atoms, and signal setter functions are allowed.
	 * Note that `server.addSignalsToClient` still requires some way to get the
	 * state.
	 *
	 * @param setters A map of setter functions to sync with the server.
	 */
	export function addSignals<Setters extends SetterMap = SetterMap>(setters: Setters): void;

	/**
	 * Unregisters from server state updates for the given keys. The signals
	 * will retain their current values, but will no longer receive updates
	 * from the server.
	 */
	export function removeSignals<Setters extends GetterMap | SetterMap = SetterMap>(...keys: (keyof Setters)[]): void;

	/**
	 * Unsubscribes from all server state updates.
	 */
	export function removeAllSignals(): void;

	/**
	 * Merges the server's state patches into the client's state, either
	 * initializing it with the full state or merging a partial patch.
	 *
	 * @param payloads The state updates received from the server.
	 */
	export function hydrate<Getters extends GetterMap = GetterMap, FixArrays extends boolean = true>(
		payloads: SyncPayload<Getters, FixArrays>[],
	): void;
}

/**
 * @server
 */
export namespace server {
	/**
	 * Subscribes a client to the given signals. When an update occurs, the client
	 * will receive a partial state patch to merge into their local state. May be
	 * called multiple times to subscribe to additional keys.
	 *
	 * Atoms, computed signals, and signal getter functions are allowed. Note
	 * that `client.addSignals` still requires some way to set the state.
	 *
	 * @param client The client receiving state updates.
	 * @param getters A map of getter functions to sync with the client.
	 */
	export function addSignalsToClient<Getters extends GetterMap = GetterMap>(client: Player, getters: Getters): void;

	/**
	 * Unsubscribes a client from receiving all state updates. To only unsubscribe
	 * from specific keys, use `removeSignalsFromClient` instead.
	 *
	 * @param client The client receiving state updates.
	 */
	export function removeClient(client: Player): void;

	/**
	 * Unsubscribes a client from receiving updates for the given keys.
	 *
	 * @param client The client receiving state updates.
	 * @param keys The keys of the state to unsubscribe from.
	 */
	export function removeSignalsFromClient<Getters extends GetterMap = GetterMap>(
		client: Player,
		...keys: (keyof Getters)[]
	): void;

	/**
	 * Uses the callback to send state updates to clients that are subscribed
	 * to state changes. Starts automatically sending updates at the interval
	 * specified in `config.interval`.
	 *
	 * @param onSync Called when sending patches to a client.
	 */
	export function connect<Getters extends GetterMap = GetterMap, FixArrays extends boolean = true>(
		onSync: (client: Player, payloads: SyncPayload<Getters, FixArrays>[]) => void,
	): void;

	/**
	 * Stops syncing state updates to clients at the automatic interval.
	 * Flushing can still be performed manually via `flush`.
	 */
	export function disconnect(): void;

	/**
	 * Immediately sends pending updates to all clients. Normally, updates are
	 * sent at the interval specified in `config.interval`, but this function
	 * can be used to force an immediate sync.
	 */
	export function flush(): void;

	/**
	 * Unsubscribes all clients, stops tracking all state, and disconnects
	 * from the automatic sync interval.
	 */
	export function reset(): void;
}

export namespace patch {
	/**
	 * Converts `nil` values to the special `None` symbol. This is useful when
	 * preparing data for serialization, since `nil` can represent both the
	 * absence of a value and the removal of a value in patches.
	 */
	export function nilToNone<T>(value: T | undefined): T | None;

	/**
	 * Compares two states and returns a patch that can be applied to the
	 * current state to produce the next state.
	 *
	 * @param currentState The current state.
	 * @param nextState The next state.
	 * @returns A patch that can be applied to the current state.
	 */
	export function diff<State, FixArrays extends boolean = true>(
		currentState: State,
		nextState: State,
	): SyncPatch<State, FixArrays>;

	/**
	 * Applies a patch to a state and returns the resulting value.
	 *
	 * @param currentState The current state.
	 * @param statePatch The patches to apply.
	 * @returns The new state with the patch applied.
	 */
	export function apply<State, FixArrays extends boolean = true>(
		currentState: State,
		statePatch: SyncPatch<State, FixArrays>,
	): State;
}

type DeepFlattenImpl<T, Prefix extends string = ""> = {
	[K in keyof T]: T[K] extends DataType | Callback
		? { [P in `${Prefix}${Exclude<K, symbol>}`]: T[K] }
		: T[K] extends object
			? DeepFlattenImpl<T[K], `${Prefix}${Exclude<K, symbol>}/`>
			: { [P in `${Prefix}${Exclude<K, symbol>}`]: T[K] };
}[keyof T];

type DeepFlatten<T> = Reconstruct<UnionToIntersection<DeepFlattenImpl<T>>>;

/**
 * Flattens a nested table into a single table with slash-separated keys.
 * Useful for recursively collecting atoms returned by modules.
 *
 * @param input A nested table.
 * @return A flattened table with slash-separated keys.
 */
export function flatten<T>(input: T): DeepFlatten<T>;

/**
 * Checks whether a value is `None`. If `true`, the value is scheduled to be
 * removed from the state when the patch is applied.
 *
 * @param value The value to check.
 * @returns `true` if the value is `None`, otherwise `false`.
 */
export function isNone(value: unknown): value is None;

/**
 * Converts a signal getter and setter into an atom. This is useful for
 * syncing client signals with the server, as the sync system requires both
 * the getter and setter to update state.
 *
 * @param getter A function that returns the current value of the signal.
 * @param setter A function that sets the value of the signal.
 * @returns An atom that can either get or set the signal's value.
 */
export function signalToAtom<T>(getter: () => T, setter: (value: ((prev: T) => T) | T) => T): Atom<T>;
