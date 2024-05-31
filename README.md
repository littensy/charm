<p align="center">
  <p align="center">
	<img width="150" height="150" src="https://raw.githubusercontent.com/littensy/charm/master/images/logo.png" alt="Logo">
  </p>
  <h1 align="center"><b>Charm</b></h1>
  <p align="center">
    Atomic state management for Roblox.
    <br />
    <a href="https://npmjs.com/package/@rbxts/charm"><strong>npm package →</strong></a>
  </p>
</p>

<div align="center">

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/littensy/charm/ci.yml?style=for-the-badge&branch=master&logo=github)
[![NPM Version](https://img.shields.io/npm/v/@rbxts/charm.svg?style=for-the-badge&logo=npm)](https://www.npmjs.com/package/@rbxts/charm)
[![GitHub License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE.md)

</div>

**Charm** is an atomic state management library inspired by [Jotai](https://jotai.org) and [Nanostores](https://github.com/nanostores/nanostores). Designed to be a more composable alternative to Reflex, Charm aims to address common criticisms of Rodux-like state containers to better address certain use cases.

> [!NOTE]
> The documentation is a work-in-progress! Please refer to the [examples](#🚀-examples) section for more information on how to use Charm.

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

## 📚 API Reference

### Charm

#### `atom(state, options?)`

#### `effect(callback)`

#### `subscribe(atom, listener)`

#### `computed(atom, options?)`

#### `observe(atom, observer)`

#### `mapped(atom, mapper)`

#### `peek(atom)`

### React

#### `useAtom(atom, dependencies?)`

### Sync

#### `sync.client(options)`

#### `Client.sync(payload)`

#### `sync.server(options)`

#### `Server.connect(callback)`

#### `Server.hydrate(player)`

---

## 🚀 Examples

### Counter atom

```ts
import { atom, subscribe } from "@rbxts/charm";

const counterAtom = atom(0);
const doubleCounterAtom = () => counterAtom() * 2;

function incrementCounter() {
	counterAtom((count) => count + 1);
}

subscribe(doubleCounterAtom, (value) => {
	print(value);
});

counterAtom(1);
incrementCounter();
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
	remotes.sync.fire(player, payload);
});

// Send initial state to a player upon request
remotes.init.connect((player) => {
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
remotes.sync.connect((payload) => {
	client.sync(payload);
});

// Request initial state from the server
remotes.init.fire();
```

---

<p align="center">
Charm is released under the <a href="LICENSE.md">MIT License</a>.
</p>

<div align="center">

[![MIT License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE.md)

</div>
