type Key = string | number | symbol;
type Cleanup = () => void;

/**
 * A reactive atom that acts as both a getter and setter. Calling the atom with
 * an argument sets its value, while calling it with no arguments returns its
 * current value.
 */
export interface Atom<T> {
	(newValue: T | ((currentValue: T) => T)): T;
	(): T;
}

export type Selector<T> = () => T;

export type Equals<T> = (current: T, incoming: T) => boolean;

/**
 * Global flags that modify the behavior of Charm's reactive system.
 */
export const globals: {
	/**
	 * Enforces synchronous, non-yielding behavior in atoms and effects.
	 * Also enables state validation in Charm Sync to catch sync errors early.
	 * Enabled if the optimization level is below 2, which is true in studio.
	 */
	strict: boolean;
	/**
	 * Enforces immutability of atoms by deep-freezing table values. Enabled
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
 * @return A tuple containing the getter and setter functions for the signal.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#signalstate-equals
 */
export function signal<T>(
	value: T,
	equals?: Equals<T>,
): LuaTuple<[() => T, (newValue: T | ((currentValue: T) => T)) => T]>;
export function signal<T>(): LuaTuple<
	[() => T | undefined, (newValue: T | ((currentValue?: T) => T | undefined)) => T | undefined]
>;

/**
 * Creates a reactive atom that acts as both a getter and setter. Calling the
 * atom with an argument sets its value, while calling it with no arguments
 * returns its current value.
 *
 * @param value The initial value of the atom. If empty, the atom's value will be `undefined`.
 * @param equals A comparator function to determine if the atom's value has changed.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#atomstate-options
 */
export function atom<T>(value: T, equals?: Equals<T>): Atom<T>;
export function atom<T>(): Atom<T | undefined>;

/**
 * Creates a new atom that is computed based on the values of other atoms.
 * The returned atom is read-only, and its value is automatically updated when
 * any atoms accessed from within the getter function change.
 *
 * If an initial value is provided, the getter will receive this value as its
 * first argument on the initial run, instead of `undefined`.
 *
 * @example
 * ```ts
 * const count = atom(1);
 * const plusOne = computed(() => count() + 1);
 * print(plusOne()); // 2
 * ```
 *
 * @param getter A function that produces the next value.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#computedcallback-options
 */
export function computed<T>(getter: (previousValue?: T) => T): () => T;

/**
 * Creates an effect that runs a callback in response to atom state changes.
 * An effect tracks which atoms are accessed during its execution, and re-runs
 * the callback when those atoms change.
 *
 * The effect callback may return a cleanup function, which gets called once,
 * either before the effect re-runs or when it is disposed.
 *
 * If the effect is called within another effect, it will be disposed when the
 * outer effect re-runs.
 *
 * @param callback The function to run when dependencies change.
 * @returns A function for disposing the effect.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#effectcallback
 */
export function effect(callback: (dispose: Cleanup) => Cleanup | void): Cleanup;

/**
 * Creates an effect scope that can capture multiple reactive effects (i.e.
 * computed, effect, subscribe) created within it so that they can be disposed
 * together.
 *
 * @param callback A function that may create reactive effects.
 * @param detached If true, the scope will not be automatically disposed of
 * when the parent scope is disposed. Defaults to false.
 * @returns A function for disposing all effects created within the scope.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#effectscopecallback-detached
 */
export function effectScope(callback: () => Cleanup | void, detached?: boolean): Cleanup;

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
export function subscribe<T>(getter: () => T, callback: (value: T, previousValue: T) => void): Cleanup;

/**
 * Creates an effect that runs the callback one immediately, and then again
 * when the value returned by the getter changes. The callback receives the new
 * value, the previous value, and a cleanup function as arguments.
 *
 * @param getter A function that returns the value to watch.
 * @param callback The function to run when the value changes.
 * @returns A function for disposing the effect.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#listengetter-callback
 */
export function listen<T>(
	getter: () => T,
	callback: (value: T, previousValue: T | undefined, dispose: Cleanup) => void,
): Cleanup;

/**
 * Creates a new atom that is computed by mapping over the entries of an
 * existing atom. The returned atom is read-only, and its value is
 * automatically updated when the source atom changes.
 *
 * @param getter A function that returns the table to map over.
 * @param mapper A function that transforms each value-key pair from the source
 * into a new value or value-key pair for the resulting table.
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
 * Calls the observer function for each unique key in the table returned by the
 * getter. The observer is called once for each key, and again when a new key
 * is added.
 *
 * The observer may return a cleanup function, which will be called when the
 * key is removed or when the entire observer is disposed.
 *
 * @param getter A function that returns the table to observe.
 * @param observer A function that is called for each key in the table.
 * @returns A function for disposing the observer.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#observegetter-observer
 */
export function observe<V, K = number>(
	getter: () => Map<K, V> | ReadonlyMap<K, V> | readonly V[],
	observer: (value: V, key: K) => Cleanup | void,
): Cleanup;
// Overload for objects
export function observe<V, K extends Key>(
	getter: () => { readonly [K in Key]: V },
	observer: (value: V, key: K) => Cleanup | void,
): Cleanup;

/**
 * Combines multiple atom updates into a single "commit" that runs effects at
 * the end of the provided callback.
 *
 * @param callback A function that performs multiple atom updates.
 * @param args Arguments to pass to the callback.
 * @returns The return value of the callback.
 */
export function batched<Args extends any[], Result>(callback: (...args: Args) => Result, ...args: Args): Result;

/**
 * Runs the callback without subscribing to atom updates or capturing inner
 * effects in the parent effect or scope.
 *
 * For an alternative that still cleans up inner effects, use `peek` instead.
 *
 * @param callback The callback function.
 * @param args Arguments to pass to the callback.
 * @returns The return value of the callback.
 */
export function untracked<Args extends any[], Result>(callback: (...args: Args) => Result, ...args: Args): Result;

/**
 * Runs the callback without subscribing to atom updates, but still captures
 * inner effects so that they dispose with the parent effect.
 *
 * To avoid capturing inner effects, use `untracked` instead.
 *
 * @param callback The callback function.
 * @param args Arguments to pass to the callback.
 * @returns The return value of the callback.
 */
export function peek<Args extends any[], Result>(callback: (...args: Args) => Result, ...args: Args): Result;

/**
 * Registers a cleanup function to the current active effect or effect scope.
 * If there is no active effect or scope, a warning is logged and the callback
 * is not registered, unless `failSilently` is set to true.
 *
 * @param callback The cleanup function to register.
 * @param failSilently If true, suppresses the warning when there is no active
 * effect or scope. Defaults to false.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#oncleanupcallback-failsilently
 */
export function onCleanup(callback: Cleanup, failSilently?: boolean): void;
