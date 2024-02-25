<p align="center">
  <p align="center">
    <img width="150" height="150" src="images/logo.png" alt="Logo">
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

## 📚 Documentation

### `atom(state)`

### `derive(...atoms, combiner)`

### `subscribe(atom, listener)`

### `observe(atom, observer)`

### `split(atom, keyExtractor?)`

---

### `Atom(state?)`

### `Atom.get(selector?)`

### `Atom.set(state)`

### `Atom.memo(equalityFn)`

### `Atom.readonly()`

### `Atom.writable(onSet?)`

### `Atom.named(label)`

### `Atom.unmount()`

---

### `useAtom(atom, selector?)`

### `useAtomState(atom)`

### `useSetAtom(atom)`

## 🚀 Examples

### Counter atom

```ts
import { atom, derive, subscribe } from "@rbxts/charm";

const counterAtom = atom(0);
const doubleCounterAtom = derive(counterAtom, (counter) => counter * 2);

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

## 🙋 Concerns

In Jotai, `atom()` returns an [atom config](https://jotai.org/docs/core/atom), and its state is managed entirely by the Provider. However, in Charm, `atom()` returns something closer to a store, and its state is managed by the atom itself.

Charm does this for simplicity in use cases outside of React, but this might go against Jotai's focus on pure functional programming. More insight is needed to determine if this is a good idea.

---

<p align="center">
Charm is released under the <a href="LICENSE.md">MIT License</a>.
</p>

<div align="center">

[![MIT License](https://img.shields.io/badge/license-mit-f4dbd6?style=for-the-badge&labelColor=302d41)](LICENSE.md)

</div>
