import { Selector } from "@rbxts/charm";

/**
 * A hook that subscribes to changes in the given atom or selector. The
 * component is re-rendered whenever the state changes.
 *
 * If the `dependencies` array is provided, the subscription to the atom or
 * selector is re-created whenever the dependencies change. Otherwise, the
 * subscription is created once when the component is mounted.
 *
 * @param callback The atom or selector to subscribe to.
 * @param dependencies An array of values that the subscription depends on.
 * @returns The current state.
 */
export function useAtom<State>(callback: Selector<State>, dependencies?: unknown[]): State;
