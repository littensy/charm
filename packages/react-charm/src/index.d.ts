import { Binding } from "@rbxts/react";

/**
 * A hook that subscribes to changes in the given atom or selector. The
 * component is re-rendered with the new state after an update.
 *
 * If the `dependencies` array is provided, a new effect is created for the
 * current `callback` when the dependencies change. Otherwise, the effect is
 * created only once, when the component is mounted.
 *
 * @param callback The atom or selector to watch.
 * @param dependencies An array of values used to memoize the callback.
 * @returns The current state.
 */
export function useAtom<T>(callback: () => T, dependencies?: any[]): T;

/**
 * A hook that subscribes to changes in the given atom or selector. Returns
 * a binding that updates when the state changes.
 *
 * If the `dependencies` array is provided, a new effect is created for the
 * current `callback` when the dependencies change. Otherwise, the effect is
 * created only once, when the component is mounted.
 *
 * @param callback The atom or selector to watch.
 * @param dependencies An array of values used to memoize the callback.
 * @returns A binding that stores the current state.
 */
export function useAtomBinding<T>(callback: () => T, dependencies?: any[]): Binding<T>;
