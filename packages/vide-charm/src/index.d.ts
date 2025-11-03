/**
 * Returns a reactive source that subscribes to the current value of the given
 * signal or getter function.
 *
 * @param getter The getter function to subscribe to.
 * @return The reactive source.
 */
export function useSignalState<T>(getter: () => T, dependencies?: any[]): () => T;

// Aliases
export { useSignalState as useAtom };
