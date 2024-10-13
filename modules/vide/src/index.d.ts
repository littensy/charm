import { Molecule } from "@rbxts/charm";

/**
 * Subscribes to the state of an atom and returns a Vide source.
 *
 * @param molecule The atom or molecule to subscribe to.
 * @returns The reactive source.
 */
export function useAtom<T>(atom: Molecule<T>): () => T;
