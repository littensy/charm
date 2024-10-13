import { Molecule } from "@rbxts/charm";

/**
 * A hook that subscribes to changes in the given atom or molecule. The
 * component is re-rendered whenever the state changes.
 *
 * If the `dependencies` array is provided, the subscription to the atom or
 * molecule is re-created whenever the dependencies change. Otherwise, the
 * subscription is created once when the component is mounted.
 *
 * @param molecule The atom or molecule to subscribe to.
 * @param dependencies An array of values that the subscription depends on.
 * @returns The current state.
 */
export function useAtom<State>(molecule: Molecule<State>, dependencies?: unknown[]): State;
