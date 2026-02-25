export type ReactiveProxy<T extends object = object> = T & {
	__track: () => void;
	__target: T;
	__signals: Map<unknown, () => unknown>;
};

/**
 * Creates a deep reactive value that tracks properties when they're accessed.
 * Returns a proxy object that subscribes to changes on any nested property
 * you read, and a function for mutating the original table.
 *
 * @example
 * ```luau
 * local users, updateUsers = reactive({
 * 	user = { name = "John", surname = "Doe" },
 * })
 *
 * effect(function()
 * 	print(users.user and `{users.user.name} {users.user.surname}`)
 * end)
 *
 * updateUsers(function(state)
 * 	state.user.name = "Jane"
 * 	state.user.surname = "Smith"
 * end)
 * ```
 *
 * @param initialValue The value to make deeply reactive.
 * @returns A proxy table and a function to mutate the original table.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
 */
export function reactive<T extends object>(
	initialValue: T,
): LuaTuple<[value: T, update: (update: T | ((initialValue: T) => void)) => T]>;

/**
 * Determines if the provided value is a reactive proxy created by `reactive()`.
 *
 * @param value A value to test.
 * @returns `true` if the value is a reactive proxy, `false` otherwise.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
 */
export function isReactive(value: unknown): boolean;

/**
 * Unwraps a reactive proxy to get the original table. If the provided value
 * is not a proxy, it is returned as-is.
 *
 * @param value A reactive proxy or a non-proxy value.
 * @returns The unwrapped target value.
 * @see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
 */
export function toRaw<T>(value: T): T;
