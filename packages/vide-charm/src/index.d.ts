/**
 * Subscribes to the state of an atom or selector. Returns a source that
 * updates when the state changes.
 *
 * @param callback The atom or selector to subscribe to.
 * @returns The reactive source.
 */
export function useAtom<T>(callback: () => T, dependencies?: any[]): () => T;
