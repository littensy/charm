type Key = string | number | symbol;

type Cleanup = () => void;

export enum ReactiveFlags {
	None = 0b000000,
	Mutable = 0b000001,
	Watching = 0b000010,
	RecursedCheck = 0b000100,
	Recursed = 0b001000,
	Dirty = 0b010000,
	Pending = 0b100000,
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
	(update: Update<T>): T;
	(): T;
}

export type Getter<T> = () => T;

export type Setter<T> = (update: Update<T>) => T;

export type Update<T> = ((currentValue: T) => T) | T;

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
export function signal<T>(initialValue: T, equals?: Equals<T>): LuaTuple<[getter: Getter<T>, setter: Setter<T>]>;
export function signal<T>(): LuaTuple<[getter: Getter<T | undefined>, setter: Setter<T | undefined>]>;

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
export function computed<T>(getter: (previousValue?: T) => T): Getter<T>;

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
 * Runs the function without subscribing to signal updates and prevents the
 * current effect or scope from tracking inner effects created within the
 * function.
 *
 * To avoid tracking signals while still allowing inner effects to be tracked
 * by parent effects/scopes, use `effectScope()` instead.
 *
 * @param fn A function that may read signals or create effects.
 * @param args Arguments to pass to the function.
 * @returns The return value of the function.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#untrackedcallback
 */
export function untracked<Args extends any[], Result>(fn: (...args: Args) => Result, ...args: Args): Result;

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
 * @param getter A function that returns the value to watch.
 * @param callback The function to run when the value changes.
 * @returns A function for disposing the effect.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#listengetter-callback
 */
export function listen<T>(getter: Getter<T>, callback: (value: T, previousValue: T | undefined) => void): Cleanup;

/**
 * Creates an effect that only runs the callback when the value returned by the
 * getter changes. The callback receives the new value and the previous value
 * as arguments.
 *
 * @param getter A function that returns the value to watch.
 * @param callback The function to run when the value changes.
 * @returns A function for disposing the effect.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#subscribegetter-callback
 */
export function subscribe<T>(getter: Getter<T>, callback: (value: T, previousValue: T) => void): Cleanup;

/**
 * Creates a new read-only signal that is computed by mapping over the entries
 * of the source table. If the key is omitted from the transform function's
 * return value, the original key is preserved.
 *
 * This function is optimized to minimize unnecessary updates by only calling
 * the transform function for entries that have changed since the last run.
 *
 * @param getter A signal or function that returns a table
 * @param transform Function that maps each entry from the source to a new entry in the mapped table
 * @see https://github.com/littensy/charm?tab=readme-ov-file#mappedgetter-transform
 */
export function mapped<VI, KI, VO, KO = KI>(
	getter: Getter<Map<KI, VI> | ReadonlyMap<KI, VI>>,
	transform: (value: VI, key: KI) => LuaTuple<[VO, KO]> | VO,
): Getter<ReadonlyMap<KO, VO>>;
// Overload for arrays
export function mapped<VI, VO, K extends Key = number>(
	getter: Getter<readonly VI[]>,
	transform: (value: VI, key: number) => LuaTuple<[VO, K]> | VO,
): Getter<K extends number ? readonly VO[] : { readonly [P in K]: VO }>;
// Overload for objects
export function mapped<VI, KI extends Key, VO, KO extends Key = KI>(
	getter: Getter<{ readonly [K in KI]: VI }>,
	transform: (value: VI, key: KI) => LuaTuple<[VO, KO]> | VO,
): Getter<{ readonly [K in KO]: VO }>;

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
 * @param callback A function that is called for each key in the table.
 * @returns A function for disposing the observer.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#observegetter-callback
 */
export function observe<V, K = number>(
	getter: Getter<Map<K, V> | ReadonlyMap<K, V> | readonly V[]>,
	callback: (value: V, key: K) => Cleanup | void,
): Cleanup;
// Overload for objects
export function observe<V, K extends Key>(
	getter: Getter<{ readonly [K in Key]: V }>,
	callback: (value: V, key: K) => Cleanup | void,
): Cleanup;

/**
 * Returns the currently active subscriber (effect or computed node).
 *
 * @return Current active subscriber or `nil`
 */
export function getActiveSub(): ReactiveNode | undefined;

/**
 * Sets the currently active subscriber (effect or computed node) and returns
 * the previous subscriber.
 *
 * @param sub New subscriber to set as active
 * @return Previous active subscriber
 */
export function setActiveSub(sub?: ReactiveNode): ReactiveNode | undefined;

/**
 * Starts a batch operation, incrementing the batch depth counter. Effects
 * will not run until the outermost batch ends.
 */
export function startBatch(): void;

/**
 * Ends a batch operation, decrementing the batch depth counter. If this is
 * the outermost batch, queued effects are flushed and run.
 */
export function endBatch(): void;
