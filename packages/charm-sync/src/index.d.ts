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
export type SyncPatch<State, Serialize extends boolean = true> = MaybeNone<State> | State extends
	| ReadonlyMap<infer K, infer V>
	| Map<infer K, infer V>
	? ReadonlyMap<K, SyncPatch<V, Serialize> | None>
	: State extends Set<infer T> | ReadonlySet<infer T>
		? ReadonlyMap<T, true | None>
		: State extends readonly (infer T)[]
			? Serialize extends true
				? ReadonlyMap<string | number, SyncPatch<T, Serialize> | None>
				: readonly (SyncPatch<T, Serialize> | None | undefined)[]
			: State extends DataType
				? State
				: State extends object
					? { readonly [P in keyof State]?: SyncPatch<State[P], Serialize> }
					: State;

/**
 * A payload that can be sent from the server to the client to synchronize
 * state between the two.
 */
export type SyncPayload<Selectors extends SelectorMap = SelectorMap, Serialize extends boolean = true> =
	| { type: "init"; data: StateOfMap<Selectors> }
	| { type: "patch"; data: SyncPatch<StateOfMap<Selectors>, Serialize> };

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
	 * Registers atoms to be kept in sync with the server. Atoms with matching
	 * keys on the server will be synced to these atoms.
	 *
	 * @param atoms An object mapping string keys to atoms to be synced.
	 */
	export function syncAtoms(atoms: { [key: string]: Atom<any> }): void;

	/**
	 * Unregisters one or more atoms from being kept in sync with the server.
	 * The atoms will retain their current values, but will no longer receive
	 * updates from the server.
	 *
	 * @param keys The keys of the atoms to stop syncing.
	 */
	export function unsyncAtoms(...keys: string[]): void;

	/**
	 * Unregisters all atoms from being kept in sync with the server. The
	 * atoms will retain their current values, but will no longer receive
	 * updates from the server.
	 */
	export function reset(): void;

	/**
	 * Applies one or more payloads received from the server to the synced
	 * atoms. Payloads are state patches or initial state updates sent by the
	 * server, and are usually received via a remote event.
	 *
	 * @param payloads The payloads to apply.
	 */
	export function applyPayloads<Atoms extends { [key: string]: Atom<any> }, Serialize extends boolean = true>(
		payloads: SyncPayload<Atoms, Serialize>[],
	): void;
}

/**
 * @server
 */
export namespace server {
	/**
	 * Registers atoms to be kept in sync with a specific client. Should be
	 * called when a player joins the game to start syncing atoms to them. Call
	 * `unsyncAtomsFromClient` or `unsyncClient` to stop syncing.
	 *
	 * Each atom should be assigned a unique key, allowing the server to re-use
	 * patches between multiple clients.
	 *
	 * @param client The player to sync atoms to.
	 * @param atoms An object mapping string keys to atoms to be synced.
	 */
	export function syncAtomsToClient(client: Player, atoms: { [key: string]: Atom<any> }): void;

	/**
	 * Unregisters one or more atoms from being kept in sync with a specific
	 * client.
	 *
	 * @param client The player to stop syncing atoms to.
	 * @param keys The keys of the atoms to stop syncing.
	 */
	export function unsyncAtomsFromClient(client: Player, ...keys: string[]): void;

	/**
	 * Unregisters all atoms from being kept in sync with a specific client.
	 * Should be called when a player leaves the game.
	 *
	 * @param client The player to stop syncing atoms to.
	 */
	export function unsyncClient(client: Player): void;

	/**
	 * Starts automatically syncing registered atoms to clients. Patches will
	 * be sent to clients whenever the atoms are updated.
	 *
	 * @param onSync The function to call when patches can be sent to a client.
	 */
	export function startSync<Atoms extends { [key: string]: Atom<any> }, Serialize extends boolean = true>(
		onSync: (client: Player, payloads: SyncPayload<Atoms, Serialize>[]) => void,
	): void;

	/**
	 * Stops automatically syncing registered atoms to clients. Patches will
	 * no longer be sent to clients until `startSync` is called again.
	 */
	export function stopSync(): void;

	/**
	 * Immediately sends pending updates and initial states to all clients.
	 * Normally, updates are sent at the interval specified in `config.interval`.
	 * Calling this function forces all pending updates to be sent immediately.
	 */
	export function flush(): void;

	/**
	 * Unregisters all atoms from being kept in sync with all clients, and
	 * stops automatic syncing.
	 */
	export function reset(): void;
}

export namespace patch {
	/**
	 * Converts `nil` values to the special `None` symbol. This is useful when
	 * preparing data for serialization, since `nil` can represent both the absence
	 * of a value and the removal of a value in patches.
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
	export function diff<State, Serialize extends boolean = true>(
		currentState: State,
		nextState: State,
	): SyncPatch<State, Serialize>;

	/**
	 * Applies a patch to a state and returns the resulting value.
	 *
	 * @param currentState The current state.
	 * @param statePatch The patches to apply.
	 * @returns The new state with the patch applied.
	 */
	export function apply<State, Serialize extends boolean = true>(
		currentState: State,
		statePatch: SyncPatch<State, Serialize>,
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

type UnionToIntersection<U> = (U extends any ? (k: U) => void : never) extends (k: infer I) => void ? I : never;

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
export function flatten<Atoms extends NestedAtomMap>(atoms: Atoms): FlattenNestedAtoms<Atoms>;

/**
 * Checks whether a value is `None`. If `true`, the value is scheduled to be
 * removed from the state when the patch is applied.
 *
 * @param value The value to check.
 * @returns `true` if the value is `None`, otherwise `false`.
 */
export function isNone(value: unknown): value is None;
