import { Binding } from "@rbxts/react";

/**
 * Returns a React state that updates when the getter function updates.
 * Re-renders the component when the value changes.
 *
 * If the `dependencies` array is provided, a new effect is created for the
 * current `getter` when the dependencies change. Otherwise, the effect is
 * created only once, when the component is mounted.
 *
 * @param getter The signal or selector to watch.
 * @param dependencies An array of values used to memoize the getter.
 * @return The current state.
 */
export function useSignalState<T>(getter: () => T, dependencies?: any[]): T;

/**
 * Returns a React binding that updates when the getter function updates.
 *
 * If the `dependencies` array is provided, a new effect is created for the
 * current `getter` when the dependencies change. Otherwise, the effect is
 * created only once, when the component is mounted.
 *
 * @param getter The atom or selector to watch.
 * @param dependencies An array of values used to memoize the getter.
 * @return A binding that stores the current state.
 */
export function useSignalBinding<T>(getter: () => T, dependencies?: any[]): Binding<T>;

// Aliases
export { useSignalState as useAtom };
