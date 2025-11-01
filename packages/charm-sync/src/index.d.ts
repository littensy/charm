import { Atom } from "@rbxts/charm";

type Key = string | number | symbol;

/**
 * Represents the removal of a value from the state.
 */
export interface None {
	readonly __none: "__none";
}

export type MaybeNone<T> = undefined extends T ? None : never;

type SelectorMap = Record<string, () => any>;

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
export type SyncPayload<Selectors extends SelectorMap = SelectorMap, FixArrays extends boolean = true> =
	| { type: "init"; data: StateOfMap<Selectors> }
	| { type: "patch"; data: SyncPatch<StateOfMap<Selectors>, FixArrays> };

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
	 * When `true`, patches will be validated before being sent to clients to
	 * enforce remote event limitations. Only checked in strict mode and if
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
	 * Registers a map of atoms to the state with the corresponding keys on the
	 * server. When the server sends updates, these atoms will be hydrated with
	 * the new values.
	 *
	 * If syncing signals instead of atoms, you can use `signalToAtom` to sync
	 * signal getters and setters as atoms.
	 *
	 * @param atoms A map of atoms to sync with the server.
	 */
	export function register(atoms: { [key: string]: Atom<any> }): void;

	/**
	 * Unregisters from server state updates for the given keys. The atoms
	 * will retain their current values, but will no longer receive updates
	 * from the server.
	 */
	export function unregister(...keys: string[]): void;

	/**
	 * Unsubscribes from all server state updates.
	 */
	export function reset(): void;

	/**
	 * Merges the server's state patches into the client's state, either
	 * initializing it with the full state or merging a partial patch.
	 *
	 * @param payloads The state updates received from the server.
	 */
	export function hydrate<Atoms extends { [key: string]: Atom<any> }, FixArrays extends boolean = true>(
		payloads: SyncPayload<Atoms, FixArrays>[],
	): void;
}

/**
 * @server
 */
export namespace server {
	/**
	 * Subscribes a client to the given atoms. When an update occurs, the client
	 * will receive a partial state patch to merge into their local state. May be
	 * called multiple times to subscribe to additional keys.
	 *
	 * Atoms, signals converted to atoms, and signal getter functions are allowed.
	 * Note that the client still requires some way to set the state, so
	 * registering signals on the client should be done through `signalToAtom()`.
	 *
	 * @param client The client receiving state updates.
	 * @param atoms A map of atoms to sync with the client.
	 */
	export function subscribeClient(client: Player, atoms: { [key: string]: Atom<any> }): void;

	/**
	 * Unsubscribes a client from receiving all state updates. To only unsubscribe
	 * from specific keys, use `unsubscribeClientFrom` instead.
	 *
	 * @param client The client receiving state updates.
	 */
	export function unsubscribeClient(client: Player): void;

	/**
	 * Unsubscribes a client from receiving updates for the given keys.
	 *
	 * @param client The client receiving state updates.
	 * @param keys The keys of the state to unsubscribe from.
	 */
	export function unsubscribeClientFrom(client: Player, ...keys: string[]): void;

	/**
	 * Uses the callback to send state updates to clients that are subscribed
	 * to state changes. Starts automatically sending updates at the interval
	 * specified in `config.interval`.
	 *
	 * @param onSync Called when sending patches to a client.
	 */
	export function connect<Atoms extends { [key: string]: Atom<any> }, FixArrays extends boolean = true>(
		onSync: (client: Player, payloads: SyncPayload<Atoms, FixArrays>[]) => void,
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

interface NestedAtomMap {
	readonly [key: string]: NestedAtomMap | Atom<any>;
}

type AppendPath<Path extends Key | undefined, Name extends Key> = undefined extends Path
	? Name
	: Name extends string
		? Path extends string
			? `${Path}/${Name}`
			: never
		: never;

type IntersectValues<T> = UnionToIntersection<{ readonly [K in keyof T]: T[K] }[keyof T]>;

export type FlattenNestedAtoms<
	Atoms extends NestedAtomMap,
	Path extends Key | undefined = undefined,
> = IntersectValues<{
	readonly [Name in keyof Atoms as AppendPath<Path, Name>]: Atoms[Name] extends Atom<any>
		? { readonly [K in AppendPath<Path, Name>]: Atoms[Name] }
		: Atoms[Name] extends NestedAtomMap
			? FlattenNestedAtoms<Atoms[Name], AppendPath<Path, Name>>
			: never;
}>;

/**
 * Flattens a nested atom map into a single object with slash-separated keys.
 * Useful for recursively collecting atoms returned by modules.
 *
 * @param atoms The nested atom map to flatten.
 * @returns A flattened atom map.
 */
export function flattenAtoms<Atoms extends NestedAtomMap>(atoms: Atoms): FlattenNestedAtoms<Atoms>;

/**
 * Checks whether a value is `None`. If `true`, the value is scheduled to be
 * removed from the state when the patch is applied.
 *
 * @param value The value to check.
 * @returns `true` if the value is `None`, otherwise `false`.
 */
export function isNone(value: unknown): value is None;
