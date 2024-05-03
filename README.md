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

**Charm** is a Roblox state management library, inspired by [Jotai](https://jotai.org). Designed to be an alternative to [Reflex](https://littensy.github.io/reflex), Charm aims to bring an atomic and composable approach to your game's state.

> [!NOTE]
> Charm is incomplete and not ready for use.

## 📦 Setup

### TypeScript

Install Charm through your package manager of choice. \
[React](https://github.com/littensy/rbxts-react) is optional, but highly recommended.

```sh
npm install @rbxts/charm
yarn add @rbxts/charm
pnpm add @rbxts/charm
```

### Wally

Add `littensy/charm` to your `wally.toml` file.

```toml
[dependencies]
Charm = "littensy/charm@VERSION"
```

## 📚 API Reference

### Charm

#### `atom(state)`

#### `effect(callback)`

#### `subscribe(atom, listener)`

#### `derive(atom, equals?)`

#### `observe(atom, observer)`

#### `map(atom, mapper)`

#### `peek(atom)`

### React

#### `useAtom(atom, dependencies?)`

### Sync

#### `sync.client(options)`

#### `Client.sync(payload)`

#### `sync.server(options)`

#### `Server.connect(callback)`

#### `Server.hydrate(player)`

## 🚀 Examples

### Counter atom

```ts
import { atom, subscribe } from "@rbxts/charm";

const counterAtom = atom(0);
const doubleCounterAtom = () => counterAtom() * 2;

subscribe(doubleCounterAtom, (value) => {
	print(value);
});

counterAtom(1);
counterAtom((count) => count + 1);
```

### Counter component

```tsx
import React from "@rbxts/react";
import { useAtom } from "@rbxts/charm";
import { counterAtom } from "./counter-atom";

function Counter() {
	const [count, setCount] = useAtom(counterAtom);

	return (
		<textlabel
			Text={`Count: ${count}`}
			Size={new UDim2(0, 100, 0, 50)}
			Event={{
				Activated: () => setCount(count + 1),
			}}
		/>
	);
}
```

---

<p align="center">
Charm is released under the <a href="LICENSE.md">MIT License</a>.
</p>

<div align="center">

[![MIT License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE.md)

</div>
