import { Atom } from "@rbxts/charm";

type Cleanup = () => void;

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
type StateOfMap<T> = {
	readonly [P in keyof T]: T[P] extends () => infer State ? State : never;
};

type DataTypes = {
	[P in keyof CheckableTypes as P extends keyof CheckablePrimitives ? never : P]: CheckableTypes[P];
};

/**
 * A type that should not be made partial in patches.
 */
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
 * Checks whether a value is `None`. If `true`, the value is scheduled to be
 * removed from the state when the patch is applied.
 *
 * @param value The value to check.
 * @returns `true` if the value is `None`, otherwise `false`.
 */
export function isNone(value: unknown): value is None;

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
	autoSerialize: boolean;
	/**
	 * When `true`, patches will be validated before being sent to clients to
	 * enforce remote event limitations. Only checked in strict mode and if
	 * `autoSerialize` is enabled. Defaults to `true`.
	 *
	 * @server
	 */
	validatePatches: boolean;
};

export namespace client {
	export function syncAtoms(atoms: { [key: string]: Atom<any> }): void;

	export function unsyncAtoms(...keys: string[]): void;

	export function reset(): void;

	export function applyPayloads<Atoms extends { [key: string]: Atom<any> }, Serialize extends boolean = true>(
		payloads: SyncPayload<Atoms, Serialize>[],
	): void;
}

export namespace server {
	export function syncAtomsToClient(client: Player, atoms: { [key: string]: Atom<any> }): void;

	export function unsyncAtomsFromClient(client: Player, ...keys: string[]): void;

	export function unsyncClient(client: Player): void;

	export function startSync<Atoms extends { [key: string]: Atom<any> }, Serialize extends boolean = true>(
		onSync: (client: Player, payloads: SyncPayload<Atoms, Serialize>[]) => void,
	): Cleanup;

	export function stopSync(): void;

	export function flush(): void;

	export function reset(): void;
}

export namespace patch {
	export function isNone(value: unknown): value is None;

	export function nilToNone<T>(value: T | undefined): T | None;

	export function diff<State, Serialize extends boolean = true>(
		currentState: State,
		nextState: State,
	): SyncPatch<State, Serialize>;

	export function apply<State, Serialize extends boolean = true>(
		state: State,
		patch: SyncPatch<State, Serialize>,
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

type FlattenNestedAtoms<Atoms extends NestedAtomMap, Path extends Key | undefined = undefined> = IntersectValues<{
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
 * @return A flattened atom map.
 */
export function flatten<Atoms extends NestedAtomMap>(atoms: Atoms): FlattenNestedAtoms<Atoms>;
