import { Atom, Selector } from "@rbxts/charm";

export = CharmSync;
export as namespace CharmSync;

type Cleanup = () => void;

declare namespace CharmSync {
	type AtomMap = Record<string, Atom<any>>;

	/**
	 * @deprecated Use `SelectorMap` instead.
	 */
	type MoleculeMap = Record<string, Selector<any>>;

	type SelectorMap = Record<string, Selector<any>>;

	/**
	 * Infers the type of the return values produced by a map of functions.
	 */
	type StateOfMap<T> = {
		[P in keyof T]: T[P] extends Selector<infer State> ? State : never;
	};

	/**
	 * A special value that denotes the absence of a value. Used to represent
	 * removed values in patches.
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
	function server<Selectors extends SelectorMap>(options: ServerOptions<Selectors>): ServerSyncer<Selectors>;

	/**
	 * Checks whether a value is `None`. If `true`, the value is scheduled to be
	 * removed from the state when the patch is applied.
	 *
	 * @param value The value to check.
	 * @returns `true` if the value is `None`, otherwise `false`.
	 */
	function isNone(value: unknown): value is None;

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
	type SyncPatch<State> =
		| MaybeNone<State>
		| (State extends ReadonlyMap<infer K, infer V> | Map<infer K, infer V>
				? ReadonlyMap<K, SyncPatch<V> | None>
				: State extends Set<infer T> | ReadonlySet<infer T>
					? ReadonlyMap<T, true | None>
					: State extends readonly (infer T)[]
						? readonly (SyncPatch<T> | None | undefined)[]
						: State extends DataType
							? State
							: State extends object
								? { readonly [P in keyof State]?: SyncPatch<State[P]> }
								: State);

	/**
	 * A payload that can be sent from the server to the client to synchronize
	 * state between the two.
	 */
	type SyncPayload<Selectors extends SelectorMap> =
		| { type: "init"; data: StateOfMap<Selectors> }
		| { type: "patch"; data: SyncPatch<StateOfMap<Selectors>> };

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

	interface ServerOptions<Selectors extends SelectorMap> {
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
	}

	interface ClientSyncer<Atoms extends AtomMap> {
		/**
		 * Applies a patch or initializes the state of the atoms with the given
		 * payload from the server.
		 *
		 * @param payloads The patches or hydration payloads to apply.
		 */
		sync(...payloads: SyncPayload<Atoms>[]): void;
	}

	interface ServerSyncer<Selectors extends SelectorMap> {
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
		connect(callback: (player: Player, ...payloads: SyncPayload<Selectors>[]) => void): Cleanup;
		/**
		 * Hydrates the client's state with the server's state. This should be
		 * called when a player joins the game and requires the server's state.
		 *
		 * @param player The player to hydrate.
		 */
		hydrate(player: Player): void;
	}
}
