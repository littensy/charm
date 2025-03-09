import { Atom, Selector } from "@rbxts/charm";

export = CharmSync;
export as namespace CharmSync;

type Cleanup = () => void;

type Key = string | number | symbol;

declare namespace CharmSync {
	type AtomMap = Record<string, Atom<any>>;

	type SelectorMap = Record<string, Selector<any>>;

	/**
	 * @deprecated Use `SelectorMap` instead.
	 */
	type MoleculeMap = SelectorMap;

	/**
	 * Infers the type of the return values produced by a map of functions.
	 */
	type StateOfMap<T> = {
		readonly [P in keyof T]: T[P] extends Selector<infer State> ? State : never;
	};

	/**
	 * Represents the removal of a value from the state.
	 */
	interface None {
		readonly __none: "__none";
	}

	type MaybeNone<T> = undefined extends T ? None : never;

	/**
	 * Creates a `ClientSyncer` object that receives patches from the server and
	 * applies them to the local state.
	 *
	 * @client
	 * @param options The atoms to synchronize with the server.
	 * @returns A `ClientSyncer` object.
	 */
	function client<Atoms extends AtomMap>(options: ClientOptions<Atoms>): ClientSyncer<Atoms>;

	/**
	 * Creates a `ServerSyncer` object that sends patches to the client and
	 * hydrates the client's state.
	 *
	 * @server
	 * @param options The atoms to synchronize with the client.
	 * @returns A `ServerSyncer` object.
	 */
	function server<Selectors extends SelectorMap, Serialize extends boolean = true>(
		options: ServerOptions<Selectors, Serialize>,
	): ServerSyncer<Selectors, Serialize>;

	/**
	 * Checks whether a value is `None`. If `true`, the value is scheduled to be
	 * removed from the state when the patch is applied.
	 *
	 * @param value The value to check.
	 * @returns `true` if the value is `None`, otherwise `false`.
	 */
	function isNone(value: unknown): value is None;

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
	 * Flattens a nested atom map into a single object with slash-separated
	 * keys. Useful for recursively collecting atoms returned by modules.
	 *
	 * @param atoms The nested atom map to flatten.
	 * @return A flattened atom map.
	 */
	function flatten<Atoms extends NestedAtomMap>(atoms: Atoms): FlattenNestedAtoms<Atoms>;

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
	 * using the `sync.isNone` function.
	 */
	type SyncPatch<State, Serialize extends boolean = true> = MaybeNone<State> | State extends
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
	type SyncPayload<Selectors extends SelectorMap, Serialize extends boolean = true> =
		| { readonly type: "init"; readonly data: StateOfMap<Selectors> }
		| { readonly type: "patch"; readonly data: SyncPatch<StateOfMap<Selectors>, Serialize> };

	interface ClientOptions<Atoms extends AtomMap> {
		/**
		 * The atoms to synchronize with the server.
		 */
		atoms: Atoms;
		/**
		 * Whether to ignore patches sent before the client has been hydrated.
		 * Defaults to `true`.
		 */
		ignoreUnhydrated?: boolean;
	}

	interface ServerOptions<Selectors extends SelectorMap, Serialize extends boolean = true> {
		/**
		 * The atoms to synchronize with the client.
		 */
		atoms: Selectors;
		/**
		 * The interval at which to send patches to the client, in seconds.
		 * Defaults to `0` (patches are sent up to once per frame). Set to a
		 * negative value to disable automatic syncing.
		 */
		interval?: number;
		/**
		 * Whether the history of state changes since the client's last update
		 * should be preserved. This is useful for values that change multiple times
		 * per frame, where each individual change is important. Defaults to `false`.
		 *
		 * If `true`, the broadcaster will send a list of payloads to the client
		 * instead of a single payload. The client will apply each payload in order
		 * to reconstruct the state's changes over time.
		 */
		preserveHistory?: boolean;
		/**
		 * When `true`, Charm will apply validation and serialize unsafe arrays
		 * to address remote event argument limitations. Defaults to `true`.
		 *
		 * This option should be disabled if your network library uses a custom
		 * serialization method (i.e. Zap, ByteNet) to prevent interference.
		 */
		autoSerialize?: Serialize;
	}

	interface ClientSyncer<Atoms extends AtomMap> {
		/**
		 * Applies a patch or initializes the state of the atoms with the given
		 * payload from the server.
		 *
		 * @param payloads The patches or hydration payloads to apply.
		 */
		sync(...payloads: SyncPayload<Atoms, boolean>[]): void;
	}

	interface ServerSyncer<Selectors extends SelectorMap, Serialize extends boolean> {
		/**
		 * Sets up a subscription to each atom that schedules a patch to be sent to
		 * the client whenever the state changes. When a change occurs, the `callback`
		 * is called with the player and the payloads to send.
		 *
		 * Note that a `payload` object should not be mutated. If you need to modify
		 * a payload, apply the changes to a copy of the object.
		 *
		 * @param callback The function to call when the state changes.
		 * @returns A cleanup function that unsubscribes all listeners.
		 */
		connect(callback: (player: Player, ...payloads: SyncPayload<Selectors, Serialize>[]) => void): Cleanup;
		/**
		 * Hydrates the client's state with the server's state. This should be
		 * called when a player joins the game and requires the server's state.
		 *
		 * @param player The player to hydrate.
		 */
		hydrate(player: Player): void;
	}
}
