import { Selector } from "@rbxts/charm";

/**
 * Subscribes to the state of an atom and returns a Vide source.
 *
 * @param callback The atom or selector to subscribe to.
 * @returns The reactive source.
 */
export function useAtom<T>(callback: Selector<T>): () => T;
