type Key = string | number | symbol;
type Cleanup = () => void;

export enum ReactiveFlags {
	None = 0b0000000,
	Mutable = 0b0000001,
	Watching = 0b0000010,
	RecursedCheck = 0b0000100,
	Recursed = 0b0001000,
	Dirty = 0b0010000,
	Pending = 0b0100000,
	Peeking = 0b1000000,
}

export interface ReactiveNode {
	deps?: Link;
	depsTail?: Link;
	subs?: Link;
	subsTail?: Link;
	flags: ReactiveFlags;
}

export interface Link {
	version: number;
	dep: ReactiveNode;
	sub: ReactiveNode;
	prevSub?: Link;
	nextSub?: Link;
	prevDep?: Link;
	nextDep?: Link;
}

export interface Atom<T> {
	(newValue: T | ((currentValue: T) => T)): T;
	(): T;
}

export type Setter<T> = (newValue: T | ((currentValue: T) => T)) => T;

export type Equals<T> = (current: T, incoming: T) => boolean;

/**
 * Global flags that modify the behavior of Charm's reactive system.
 */
export const flags: {
	/**
	 * Enforces synchronous, non-yielding behavior in signals and effects.
	 * Also enables state validation in Charm Sync to catch sync errors early.
	 * Enabled if the optimization level is below 2, which is true in studio.
	 */
	strict: boolean;
	/**
	 * Enforces immutability of tables by deep-freezing table values. Enabled
	 * if the optimization level is below 2, which is true in studio.
	 */
	frozen: boolean;
	/**
	 * Whether parent effects should track inner effects and clean them up
	 * when the parent effect re-runs. This is usually desirable, but can be
	 * disabled to revert to the old behavior. Defaults to `true`.
	 */
	trackInnerEffects: boolean;
};

/**
 * Creates a reactive signal that stores a value and notifies subscribers when
 * the value changes. The signal provides both a getter and a setter.
 *
 * @param initialValue The initial value of the signal.
 * @param equals A comparator function to determine if the signal's value has changed.
 * @returns A tuple containing the getter and setter functions for the signal.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#signalinitialValue-equals
 */
export function signal<T>(
	initialValue: T,
	equals?: Equals<T>,
): LuaTuple<[getter: () => T, setter: (newValue: T | ((currentValue: T) => T)) => T]>;
export function signal<T>(): LuaTuple<
	[getter: () => T | undefined, setter: (newValue: T | ((currentValue?: T) => T | undefined)) => T | undefined]
>;

/**
 * Creates a reactive atom that acts as both a signal getter and setter.
 * Calling the atom with an argument sets its value, while calling it with no
 * arguments returns its current value.
 *
 * @param initialValue The initial value of the atom. If empty, the atom's value will be `nil`.
 * @param equals A comparator function to determine if the atom's value has changed.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#atominitialValue-equals
 */
export function atom<T>(initialValue: T, equals?: Equals<T>): Atom<T>;
export function atom<T>(): Atom<T | undefined>;

/**
 * Creates a new read-only signal that is computed based on the values of
 * other signals. The computed signal's value is automatically updated when a
 * change is detected in any of its dependencies.
 *
 * @param getter A function that produces the next value.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#computedgetter
 */
export function computed<T>(getter: (previousValue?: T) => T): () => T;

/**
 * Creates an effect that runs a callback in response to signal state changes.
 * An effect tracks which signals are accessed during its execution, and runs
 * the callback when those signals change.
 *
 * The effect callback may return a cleanup function, which gets called once,
 * either before the effect re-runs or when it is disposed.
 *
 * If the effect is called within another effect, it will be disposed when the
 * parent effect re-runs.
 *
 * @param fn The function to run when dependencies change.
 * @returns A function for disposing the effect.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#effectcallback
 */
export function effect(fn: () => Cleanup | void): Cleanup;

/**
 * Creates an effect scope that can capture reactive effects and computed
 * signals created within it so that they can be disposed together.
 *
 * @param fn A function that may create reactive effects.
 * @param detached If true, the scope will not be automatically disposed of when the parent scope is disposed. Defaults to false.
 * @returns A function for disposing all effects created within the scope.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#effectscopecallback-detached
 */
export function effectScope(fn: () => Cleanup | void, detached?: boolean): Cleanup;

/**
 * Allows you to manually trigger updates for downstream dependencies when
 * you've directly mutated a signal's value without using the signal setter.
 *
 * @param fn The dependency or a function that calls multiple dependencies.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#triggercallback
 */
export function trigger(fn: () => void): void;

/**
 * Binds the cleanup function to the current active effect or effect scope. If
 * there is no active effect, a warning is logged, unless `failSilently` is
 * set to `true`.
 *
 * @param fn The cleanup function to register.
 * @param failSilently If `true`, suppresses the warning when there is no active effect or scope. Defaults to `false`.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#oncleanupcallback-failsilently
 */
export function onCleanup(fn: Cleanup, failSilently?: boolean): void;

/**
 * Runs the function without subscribing to signal updates or capturing inner
 * effects in the parent effect or scope.
 *
 * For an alternative that still cleans up inner effects, use `peek` instead.
 *
 * @param fn A function that may read signals or create effects.
 * @param args Arguments to pass to the function.
 * @returns The return value of the function.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#untrackedcallback
 */
export function untracked<Args extends any[], Result>(fn: (...args: Args) => Result, ...args: Args): Result;

/**
 * Runs the function without subscribing to signal updates, but still captures
 * inner effects so that they dispose with the parent effect.
 *
 * To avoid capturing inner effects, use `untracked` instead.
 *
 * @param fn A function that may read signals.
 * @param args Arguments to pass to the function.
 * @returns The return value of the function.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#peekcallback
 */
export function peek<Args extends any[], Result>(fn: (...args: Args) => Result, ...args: Args): Result;

/**
 * Combines multiple updates into a single "commit" that runs effects and
 * computed signals after the provided function finishes running.
 *
 * @param fn A function that performs multiple updates.
 * @param args Arguments to pass to the function.
 * @returns The return value of the function.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#batchcallback
 */
export function batch<Args extends any[], Result>(fn: (...args: Args) => Result, ...args: Args): Result;

/**
 * Creates an effect that runs the callback one immediately, and then again
 * when the value returned by the getter changes. The callback receives the new
 * value and the previous value as arguments.
 *
 * Effects created within the callback are cleaned up when the listener runs
 * or the listener is disposed.
 *
 * @param getter A function that returns the value to watch.
 * @param fn The function to run when the value changes.
 * @returns A function for disposing the effect.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#listengetter-callback
 */
export function listen<T>(getter: () => T, fn: (value: T, previousValue: T | undefined) => void): Cleanup;

/**
 * Creates an effect that only runs the callback when the value returned by the
 * getter changes. The callback receives the new value and the previous value
 * as arguments.
 *
 * Effects created within the callback are cleaned up when the listener runs
 * or the listener is disposed.
 *
 * @param getter A function that returns the value to watch.
 * @param fn The function to run when the value changes.
 * @returns A function for disposing the effect.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#subscribegetter-callback
 */
export function subscribe<T>(getter: () => T, fn: (value: T, previousValue: T) => void): Cleanup;

/**
 * Creates a new read-only signal that is computed by mapping over the entries
 * of an existing atom. If the key is omitted from the mapper's return value,
 * the original key is preserved.
 *
 * @param getter Returns the table to map over.
 * @param mapper Transforms each value-key pair from the source into a new value or value-key pair for the resulting table.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#mappedgetter-mapper
 */
export function mapped<VI, KI, VO, KO = KI>(
	getter: () => Map<KI, VI> | ReadonlyMap<KI, VI>,
	mapper: (value: VI, key: KI) => LuaTuple<[VO, KO]> | VO,
): () => ReadonlyMap<KO, VO>;
// Overload for arrays
export function mapped<VI, VO, K extends Key = number>(
	getter: () => readonly VI[],
	mapper: (value: VI, key: number) => LuaTuple<[VO, K]> | VO,
): () => K extends number ? readonly VO[] : { readonly [P in K]: VO };
// Overload for objects
export function mapped<VI, KI extends Key, VO, KO extends Key = KI>(
	getter: () => { readonly [K in KI]: VI },
	mapper: (value: VI, key: KI) => LuaTuple<[VO, KO]> | VO,
): () => { readonly [K in KO]: VO };

/**
 * Calls the callback function for each unique key in the table returned by the
 * getter. The callback is called once for each key, and again when a new key
 * is added.
 *
 * The callback may return a cleanup function, which will be called when the
 * key is removed or when the entire callback is disposed.
 *
 * Effects created within the callback are cleaned up when the item is removed
 * from the table or when the callback is disposed.
 *
 * @param getter A function that returns the table to observe.
 * @param fn A function that is called for each key in the table.
 * @returns A function for disposing the observer.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#observegetter-callback
 */
export function observe<V, K = number>(
	getter: () => Map<K, V> | ReadonlyMap<K, V> | readonly V[],
	fn: (value: V, key: K) => Cleanup | void,
): Cleanup;
// Overload for objects
export function observe<V, K extends Key>(
	getter: () => { readonly [K in Key]: V },
	fn: (value: V, key: K) => Cleanup | void,
): Cleanup;

/**
 * Disables recursive checks for the current effect or computed signal.
 * Useful for effects that intentionally update signals they depend on.
 *
 * @example
 * ```ts
 * effect(() => {
 * 	recursive();
 * 	setCount(getCount() + 1);
 * })
 * ```
 */
export function recursive(): void;

/**
 * Creates a deep reactive value that tracks properties when they're accessed.
 * Returns a proxy object that subscribes to changes on any nested property
 * you read, and a function for mutating the original table.
 *
 * @example
 * ```luau
 * local users, setUsers = reactive({
 * 	user = { name = "John", surname = "Doe" },
 * })
 *
 * effect(function()
 * 	print(users.user and `{users.user.name} {users.user.surname}`)
 * end)
 *
 * setUsers(function(state)
 * 	state.user.name = "Jane"
 * 	state.user.surname = "Smith"
 * end)
 * ```
 *
 * @param initialValue The value to make deeply reactive.
 * @return A proxy table that tracks reads to nested properties.
 * @return A function for updating the original table.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
 */
export function reactive<T extends object>(
	initialValue: T,
): LuaTuple<[value: T, setter: (update: T | ((initialValue: T) => void)) => T]>;

export function getActiveSub(): ReactiveNode | undefined;

export function setActiveSub(sub?: ReactiveNode): ReactiveNode | undefined;

export function startBatch(): void;

export function endBatch(): void;
