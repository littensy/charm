<p align="center">
  <p align="center">
	<img width="150" height="150" src="https://raw.githubusercontent.com/littensy/charm/main/images/logo.png" alt="Logo">
  </p>
  <h1 align="center"><b>Charm</b></h1>
  <p align="center">
    Atomic state management for Roblox.
    <br />
    <a href="https://npmjs.com/package/@rbxts/charm"><strong>npm package →</strong></a>
  </p>
</p>

<div align="center">

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/littensy/charm/ci.yml?style=for-the-badge&branch=main&logo=github)
[![NPM Version](https://img.shields.io/npm/v/@rbxts/charm.svg?style=for-the-badge&logo=npm)](https://www.npmjs.com/package/@rbxts/charm)
[![GitHub License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE.md)

</div>

**Charm** is an atomic state management library inspired by [Jotai](https://jotai.org) and [Nanostores](https://github.com/nanostores/nanostores). Designed to be a more composable alternative to Reflex, Charm aims to address common criticisms of Rodux-like state containers to better address certain use cases.

## 🍀 Features

- ⚛️ **Manage state with _atoms_.** Decompose state into small, distinct containers called _atoms_, as opposed to combining them into a single store.

- 💪 **Minimal, yet powerful.** No concept of actions or middleware — write simple functions to read from and write to state.

- 🔬 **Immediate updates.** Listeners run asynchronously by default, avoiding the cascading effects of deferred updates and improving responsiveness.

- 🦄 **Like magic.** Selector functions can be subscribed to as-is — their memoization and dependencies are resolved for you.

---

## 📦 Setup

Install Charm for roblox-ts using your package manager of choice.

```sh
npm install @rbxts/charm
yarn add @rbxts/charm
pnpm add @rbxts/charm
```

Alternatively, add `littensy/charm` to your `wally.toml` file.

```toml
[dependencies]
Charm = "littensy/charm@VERSION"
```

---

## 📚 Reference

### `atom(state, options?)`

Call `atom` to create a state container with the value `state`.

```ts
const nameAtom = atom("John");
const todosAtom = atom<string[]>([]);
```

#### Parameters

- `state`: The value to assign to the atom initially.

- **optional** `options`: An object that configures the behavior of this atom.

  - **optional** `equals`: An equality function to determine whether the state has changed. By default, strict equality (`===`) is used.

#### Returns

The `atom` constructor returns an atom function with two possible operations:

1. **Read the state.** Call the atom without arguments to get the current state.
2. **Set the state.** Pass a new value or an updater function to change the state.

```ts
function newTodo() {
	nameAtom("Jane");
	nameAtom(); // "Jane"
	todosAtom((todos) => [...todos, "New todo"]);
}
```

---

### `subscribe(atom, listener)`

Call `subscribe` to listen for changes to an atom. Changes to the atom will immediately notify all subscribers, passing the new state and the previous state as arguments.

```ts
const nameAtom = atom("John");

subscribe(nameAtom, (name, prevName) => {
	print(name);
});
```

You may also pass a _molecule_, or a function that derives a value from one or more atoms. The molecule will be memoized and only re-run when its dependencies change.

```ts
const getUppercase = () => nameAtom().upper();

subscribe(getUppercase, (name) => {
	print(name);
});
```

#### Parameters

- `atom`: An atom or molecule that you want to subscribe to. This can be an atom, or a function that reads from one or more atoms.

- `listener`: A function that will be called whenever the atom changes. The listener will receive the new state and the previous state as arguments.

#### Returns

`subscribe` returns a cleanup function.

---

### `effect(callback)`

Call `effect` to declare a side effect that runs when any atom that it depends on changes. The effect will run immediately and whenever its dependencies change.

```ts
const nameAtom = atom("John");

effect(() => {
	print(nameAtom());
	return () => {
		print("Changing name!");
	};
});
```

#### Parameters

- `callback`: The function that runs your effect. The function is called once to retrieve its dependencies, and then again whenever they change. Your callback may return a cleanup function to run when the effect is removed or about to re-run.

#### Returns

`effect` returns a cleanup function.

---

### `computed(molecule, options?)`

Call `computed` when you want to derive an expensive value from one or more atoms. The derived value will be memoized and only re-run when its dependencies change.

```ts
const todosAtom = atom<string[]>([]);
const mapToUppercase = computed(() => {
	return todosAtom().map((todo) => todo.upper());
});
```

`computed` is useful when you have multiple subscribers that depend on the same derived value. By memoizing the value, you can avoid re-calculating it for each subscriber.

#### Parameters

- `molecule`: A function that reads from one or more atoms and returns a derived value.

- **optional** [`options`](#parameters): An object that configures the behavior of this atom.

#### Returns

`computed` returns a read-only atom.

---

### `observe(atom, factory)`

Call `observe` to run the factory when a key is added to the atom's state. Your factory can return a cleanup function to run when the key is removed or the observer is disposed.

```ts
const todosAtom = atom<{ [Id in string]?: Todo }>({});

observe(todosAtom, (todo, key) => {
	print(todo);
	return () => {
		print("Removing todo!");
	};
});
```

#### Parameters

- `atom`: An atom or molecule that you want to observe. This can be a primitive atom, or a function that reads from one or more atoms. The atom should return a dictionary or an array of objects.

- `factory`: A function called for each key in the atom's state. The factory will receive the entry as an argument and should return a cleanup function.

#### Returns

`observe` returns a cleanup function.

#### Caveats

- The factory will only run when a key is added or removed, not when the value at that key changes. If your data is not keyed by a unique and stable identifier, consider using `mapped` to transform it into a keyed object before passing it to `observe`.

---

### `mapped(atom, mapper)`

Call `mapped` to transform the key-value pairs of an atom's state. The mapper function will be called for each key-value pair in the atom's state, and the result will be stored in a new atom.

```ts
const todosAtom = atom<Todo[]>([]);
const todosById = mapped(todosAtom, (todo, index) => {
	return $tuple(todo, todo.id);
});
```

#### Parameters

- `atom`: An atom or molecule that you want to map. This can be a primitive atom, or a function that reads from one or more atoms. The atom should return a dictionary or an array of objects.

- `mapper`: A function called for each key-value pair in the atom's state. The mapper will receive the entry as an argument and should return a new key-value pair. The value you return determines the type of the mapped atom:

  - If you return a tuple, the mapped atom returns a dictionary with the first element as the value and the second element as the key.

  - If you return a value without a key, the mapped atom returns an array of the given values in the order they were mapped.

  - If the first element is `undefined`, the entry will be omitted from the mapped atom.

#### Returns

`mapped` returns a read-only atom.

---

### `peek(value)`

Call `peek` to get the current state of an atom without tracking it as a dependency in functions like `effect` and `subscribe`.

```ts
const nameAtom = atom("John");
const ageAtom = atom(25);

effect(() => {
	const name = nameAtom();
	const age = peek(ageAtom);
});
```

#### Parameters

- `value`: Any value. If the value is an atom, `peek` will return the current state of the atom without tracking it. Otherwise, it will return the value as-is.

- **optional** `...args`: Additional arguments to pass to the value if it is a function.

#### Returns

`peek` returns the current state of the atom. If the value is not a function, it will return the value as-is.

---

### `batch(callback)`

Call `batch` to group multiple state changes into a single update. The callback will run immediately and listeners will only be notified once all changes have been applied.

```ts
const nameAtom = atom("John");
const ageAtom = atom(25);

batch(() => {
	nameAtom("Jane");
	ageAtom(26);
});
```

#### Parameters

- `callback`: A function that makes multiple state changes. The changes will be batched together and listeners will only be notified once all changes have been applied.

#### Returns

`batch` does not return anything.

---

## 📘 React

### `useAtom(atom, dependencies?)`

Call `useAtom` at the top-level of a React component to read from an atom.

```tsx
import { useAtom } from "@rbxts/charm";
import { todosAtom } from "./todos-atom";

function TodosApp() {
	const todos = useAtom(todosAtom);
	// ...
}
```

By default, the atom is subscribed to once when the component initially mounts. Optionally, you may pass an array of dependencies to `useAtom` if your atom should be memoized based on other values.

```tsx
const todos = useAtom(searchTodos(filter), [filter]);
```

#### Parameters

- `atom`: An atom or molecule that you want to read from. This can be an atom, or a function that reads from one or more atoms.

- **optional** `dependencies`: An array of values that the atom depends on. If the dependencies change, the atom will be re-subscribed to.

#### Returns

`useAtom` returns the current state of the atom.

---

## 📗 Charm Sync

### `sync.client(options)`

Call `sync.client` to create a client sync object. The object will sync the client's copy of the state with the server's state.

```ts
import { sync } from "@rbxts/charm";

const client = sync.client({ atoms: atomsToSync });

remotes.syncState.connect((payload) => {
	client.sync(payload);
});

remotes.requestState.fire();
```

#### Parameters

- `options`: An object to configure the client syncer.

  - `atoms`: An object containing the atoms to sync. The keys should match the keys on the server.

#### Returns

`sync.client` returns a client sync object. The sync object has the following methods:

- `client.sync(payload)` applies a state update from the server.

#### Caveats

- The client sync object does not handle network communication. You must implement your own network layer to send and receive state updates. This includes requesting the initial state, which is implemented via `requestState` in the example above.

---

### `sync.server(options)`

Call `sync.server` to create a server sync object. The object handles sending state updates to clients at a specified interval, and hydrating clients with the initial state.

```ts
import { sync } from "@rbxts/charm";

const server = sync.server({ atoms: atomsToSync });

server.connect((player, payload) => {
	remotes.syncState.fire(player, payload);
});

remotes.requestState.connect((player) => {
	server.hydrate(player);
});
```

#### Parameters

- `options`: An object to configure the server syncer.

  - `atoms`: An object containing the atoms to sync. The keys should match the keys on the client.

  - **optional** `interval`: The interval at which to send state updates to clients. Defaults to `0`, meaning updates are sent on the next frame.

#### Returns

`sync.server` returns a server sync object. The sync object has the following methods:

- `server.connect(callback)` registers a callback to send state updates to clients. The callback will receive the player and the payload to send, and should send the payload to the client. The payload should not be mutated, so changes should be applied to a copy of the payload.

- `server.hydrate(player)` sends the initial state to a player, calling the callback passed to `connect` with a payload containing the initial state.

#### Caveats

- The server sync object does not handle network communication. You must implement your own network layer to send and receive state updates. This includes sending the initial state, which is implemented via `requestState` in the example above.

---

## 🚧 Development

Charm provides a debug mode to help you identify potential bugs in your project. To enable debug mode, set the global `_G.__DEV__` flag to `true`.

Currently, the debug flag enables the following checks:

- Molecules, listeners, and batched functions are not allowed to yield, and will throw an error if they do.

- Server state is validated before sending to clients. If the state is not serializable, an error will be thrown. A list of common cases can be found in the [source code](src/__tests__/sync/validate.spec.luau).

---

## 🚀 Examples

### Counter atom

```ts
import { atom, subscribe } from "@rbxts/charm";

const counterAtom = atom(0);

// Create a derived atom that returns double the counter value
const doubleCounterAtom = () => counterAtom() * 2;

// Runs after counterAtom is updated and prints double the new value
subscribe(doubleCounterAtom, (value) => {
	print(value);
});

counterAtom(1); // 2
counterAtom((count) => count + 1); // 4
```

### Counter component

```tsx
import React from "@rbxts/react";
import { useAtom } from "@rbxts/charm";
import { counterAtom, incrementCounter } from "./counter-atom";

function Counter() {
	const count = useAtom(counterAtom);

	return (
		<textlabel
			Text={`Count: ${count}`}
			Size={new UDim2(0, 100, 0, 50)}
			Event={{
				Activated: () => incrementCounter(),
			}}
		/>
	);
}
```

### Server-client sync

Charm provides client and server objects for synchronizing state between the server and clients. Start by defining a module (or creating an object) exporting the atoms you want to sync:

```ts
export { counterAtom } from "./counter-atom";
export { writerAtom } from "./writer-atom";
```

Then, on the server, create a server sync object and pass in the atoms to sync. Use remote events to broadcast state updates and send initial state to clients upon request.

```ts
import { sync } from "@rbxts/charm";
import { remotes } from "./remotes";
import * as atoms from "./atoms";

const server = sync.server({ atoms });

// Broadcast a state update to a specific player
server.connect((player, payload) => {
	remotes.syncState.fire(player, payload);
});

// Send initial state to a player upon request
remotes.requestState.connect((player) => {
	server.hydrate(player);
});
```

Finally, on the client, create a client sync object and apply incoming state changes.

```ts
import { sync } from "@rbxts/charm";
import { remotes } from "./remotes";
import * as atoms from "./atoms";

const client = sync.client({ atoms });

// Listen for incoming state changes from the server
remotes.syncState.connect((payload) => {
	client.sync(payload);
});

// Request initial state from the server
remotes.requestState.fire();
```

---

<p align="center">
Charm is released under the <a href="LICENSE.md">MIT License</a>.
</p>

<div align="center">

[![MIT License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE.md)

</div>
