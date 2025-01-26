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

**Charm** is an atomic and immutable state management library, inspired by [Jotai](https://jotai.org) and [Nanostores](https://github.com/nanostores/nanostores). Store your state in atoms, and write your own functions to read, write, and observe state.

See an example of Charm's features in [this example repository](https://github.com/littensy/charm-example).

## 🍀 Features

-   ⚛️ **Manage state with _atoms_.** Decompose state into independent containers called _atoms_, as opposed to combining them into a single store.

-   💪 **Minimal, yet powerful.** Less boilerplate — write simple functions to read from and write to state.

-   🔬 **Immediate updates.** Listeners run asynchronously by default, avoiding the cascading effects of deferred updates and improving responsiveness.

-   🦄 **Like magic.** Selector functions can be subscribed to as-is — with implicit dependency tracking, atoms are captured and memoized for you.

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

## 🐛 Debugging

Charm provides a debug mode to help you identify potential bugs in your project. To enable debug mode, set the global `_G.__DEV__` flag to `true` before importing Charm.

Enabling `__DEV__` adds a few helpful features:

-   Better error handling for selectors, subscriptions, and batched functions:

    -   Errors provide the function's name and line number.
    -   Yielding in certain functions will throw an error.

-   Server state is validated for [remote event limitations](https://create.roblox.com/docs/scripting/events/remote#argument-limitations) before being passed to the client.

Enabling debug mode in unit tests, storybooks, and other development environments can help you catch potential issues early. However, remember to turn off debug mode in production to avoid the performance overhead.

---

## 📚 Reference

### `atom(state, options?)`

Atoms are the building blocks of Charm. They are functions that hold a single value, and calling them can read or write to that value. Atoms, or any function that reads from atoms, can also be [subscribed](#subscribecallback-listener) to.

Call `atom` to create a state container initialized with the value `state`.

```luau
local nameAtom = atom("John")
local todosAtom: Atom<{ string }> = atom({})
```

#### Parameters

-   `state`: The value to assign to the atom initially.

-   **optional** `options`: An object that configures the behavior of this atom.

    -   **optional** `equals`: An equality function to determine whether the state has changed. By default, strict equality (`==`) is used.

#### Returns

The `atom` constructor returns an atom function with two possible operations:

1. **Read the state.** Call the atom without arguments to get the current state.
2. **Set the state.** Pass a new value or an updater function to change the state.

```luau
local function newTodo()
	nameAtom("Jane")

	todosAtom(function(todos)
		todos = table.clone(todos)
		table.insert(todos, "Buy milk")
		return todos
	end)

	print(nameAtom()) --> "Jane"
end
```

---

### `subscribe(callback, listener)`

Call `subscribe` to listen for changes in an atom or selector function. When the function's result changes, subscriptions are immediately called with the new state and the previous state.

```luau
local nameAtom = atom("John")

local cleanup = subscribe(nameAtom, function(name, prevName)
	print(name)
end)

nameAtom("Jane") --> "Jane"
```

You may also pass a selector function that calls other atoms. The function will be memoized and only runs when its atom dependencies update.

```luau
local function getUppercase()
	return string.upper(nameAtom())
end

local cleanup = subscribe(getUppercase, function(name)
	print(name)
end)

nameAtom("Jane") --> "JANE"
```

#### Parameters

-   `callback`: The function to subscribe to. This may be an atom or a selector function that depends on an atom.

-   `listener`: The listener is called when the result of the callback changes. It receives the new state and the previous state as arguments.

#### Returns

`subscribe` returns a cleanup function.

---

### `effect(callback)`

Call `effect` to track state changes in all atoms read within the callback. The callback will run once to retrieve its dependencies, and then again whenever they change. Your callback may return a cleanup function to run when the effect is removed or about to re-run.

```luau
local nameAtom = atom("John")

local cleanup = effect(function()
	print(nameAtom())
	return function()
		print("Cleanup function called!")
	end
end)
```

Because `effect` implicitly tracks all atoms read within the callback, it might be useful to exclude atoms that should not trigger a re-run. You can use [`peek`](#peekvalue) to read from atoms without tracking them as dependencies.

#### Parameters

-   `callback`: The function to track for state changes. The callback will run once to retrieve its dependencies, and then again whenever they change.

#### Returns

`effect` returns a cleanup function.

#### Caveats

-   **If your effect should disconnect itself, use the `cleanup` argument.** Because effects run immediately, your effect may run before a `cleanup` function is returned. To disconnect an effect from the inside, use the argument passed to your effect instead:
    ```lua
    effect(function(cleanup)
    	if condition() then
    		cleanup()
    	end
    end)
    ```

---

### `computed(callback, options?)`

Call `computed` when you want to derive a new atom from one or more atoms. The callback will be memoized, meaning that subsequent calls to the atom return a cached value that is only re-calculated when the dependencies change.

```luau
local todosAtom: Atom<{ string }> = atom({})
local mapToUppercase = computed(function()
	local result = table.clone(todosAtom())
	for key, todo in result do
		result[key] = string.upper(todo)
	end
	return result
end)
```

Because `computed` implicitly tracks all atoms read within the callback, it might be useful to exclude atoms that should not trigger a re-run. You can use [`peek`](#peekvalue) to read from atoms without tracking them as dependencies.

This function is also useful for optimizing `effect` calls that depend on multiple atoms. For instance, if an effect derives some value from two atoms, it will run twice if both atoms change at the same time. Using `computed` can group these dependencies together and avoid re-running side effects.

#### Parameters

-   `callback`: A function that returns a new value depending on one or more atoms.

-   **optional** [`options`](#parameters): An object that configures the behavior of this atom.

#### Returns

`computed` returns a read-only atom.

---

### `observe(callback, factory)`

Call `observe` to create an instance of `factory` for each key present in a dictionary or array. Your factory can return a cleanup function to run when the key is removed or the observer is cleaned up.

> [!NOTE]
> Because `observe` tracks the lifetime of each key in your data, your keys must be unique and unchanging. If your data is not keyed by unique and stable identifiers, consider using [`mapped`](#mappedcallback-mapper) to transform it into a keyed object before passing it to `observe`.

```luau
local todosAtom: Atom<{ [string]: Todo }> = atom({})

local cleanup = observe(todosAtom, function(todo, key)
	print(`Added {key}: {todo.name}`)
	return function()
		print(`Removed {key}`)
	end
end)
```

#### Parameters

-   `callback`: An atom or selector function that returns a dictionary or an array of values. When a key is added to the state, the factory will be called with the new key and its initial value.

-   `factory`: A function that will be called whenever a key is added or removed from the atom's state. The callback will receive the key and the entry's initial value as arguments, and may return a cleanup function.

#### Returns

`observe` returns a cleanup function.

---

### `mapped(callback, mapper)`

Call `mapped` to transform the keys and values of your state. The `mapper` function will be called for each key-value pair in the atom's state, and the new keys and atoms will be stored in a new atom.

```luau
local todosAtom: Atom<{ Todo }> = atom({})
local todosById = mapped(todosAtom, function(todo, index)
	return todo, todo.id
end)
```

#### Parameters

-   `callback`: The function whose result you want to map over. This can be an atom or a selector function that reads from atoms.

-   `mapper`: The mapper is called for each key in your state. Given the current value and key, it should return a new corresponding value and key:

    1. Return a single value to map the table's original key to a new value.
    2. Return two values, the first being the value and the second being the key, to update both keys and values.
    3. Return `nil` for the value to remove the key from the resulting table.

#### Returns

`mapped` returns a read-only atom.

---

### `peek(value, ...)`

Call `peek` to call a function without tracking it as the dependency of an effect or a selector function.

```luau
local nameAtom = atom("John")
local ageAtom = atom(25)

effect(function()
	local name = nameAtom()
	local age = peek(ageAtom)
end)
```

#### Parameters

-   `value`: Any value. If the value is a function, `peek` will call it without tracking dependencies and return the result.

-   **optional** `...args`: Additional arguments to pass to the value if it is a function.

#### Returns

`peek` returns the result of the given function. If the value is not a function, it will return the value as-is.

---

### `batch(callback)`

Call `batch` to defer state changes until after the callback has run. This is useful when you need to make multiple changes to the state and only want listeners to be notified once.

```luau
local nameAtom = atom("John")
local ageAtom = atom(25)

batch(function()
	nameAtom("Jane")
	ageAtom(26)
end)
```

#### Parameters

-   `callback`: A function that updates atoms. Listeners will only be notified once all changes have been applied.

#### Returns

`batch` does not return anything.

---

## 📦 React

### Setup

Install the React bindings for Charm using your package manager of choice.

```sh
npm install @rbxts/react-charm
yarn add @rbxts/react-charm
pnpm add @rbxts/react-charm
```

```toml
[dependencies]
ReactCharm = "littensy/react-charm@VERSION"
```

---

### `useAtom(callback, dependencies?)`

Call `useAtom` at the top-level of a React component to read from an atom or selector. The component will re-render when the value changes.

```luau
local todosAtom = require(script.Parent.todosAtom)

local function Todos()
	local todos = useAtom(todosAtom)
	-- ...
end
```

If your selector depends on the component's state or props, remember to pass them in a dependency array. This prevents skipped updates when an untracked parameter of the selector changes.

```luau
local todos = useAtom(function()
	return searchTodos(props.filter)
end, { props.filter })
```

#### Parameters

-   `callback`: An atom or selector function that depends on an atom.

-   **optional** `dependencies`: An array of outside values that the selector depends on. If the dependencies change, the subscription is re-created and the component re-renders with the new state.

#### Returns

`useAtom` returns the current state of the atom.

---

## 📦 Vide

### Setup

Install the Vide bindings for Charm using your package manager of choice.

```sh
npm install @rbxts/vide-charm
yarn add @rbxts/vide-charm
pnpm add @rbxts/vide-charm
```

```toml
[dependencies]
VideCharm = "littensy/vide-charm@VERSION"
```

---

### `useAtom(callback)`

Call `useAtom` in any scope to create a Vide source that returns the current state of an atom or selector.

```luau
local todosAtom = require(script.Parent.todosAtom)

local function Todos()
	local todos = useAtom(todosAtom)
	-- ...
end
```

#### Parameters

-   `callback`: An atom or selector function that depends on an atom.

#### Returns

`useAtom` returns a Vide source.

---

## 📗 Charm Sync

### Setup

The Charm Sync package provides server-client synchronization for your Charm atoms. Install it using your package manager of choice.

```sh
npm install @rbxts/charm-sync
yarn add @rbxts/charm-sync
pnpm add @rbxts/charm-sync
```

```toml
[dependencies]
CharmSync = "littensy/charm-sync@VERSION"
```

---

### `server(options)`

Call `server` to create a server sync object. This synchronizes every client's atoms with the server's state by sending partial patches that the client merges into its state.

```luau
local syncer = CharmSync.server({
	-- A dictionary of the atoms to sync, matching the client's
	atoms = atomsToSync,
	-- The minimum interval between state updates
	interval = 0,
	-- Whether to send a full history of changes made to the atoms (slower)
	preserveHistory = false,
	-- Whether to apply fixes for remote event limitations. Disable this option
	-- when using a network library with custom ser/des, like ByteNet or Zap.
	autoSerialize = true,
})

-- Sends state updates to clients when a synced atom changes.
-- Omitting sensitive information and data serialization can be done here.
syncer:connect(function(player, ...)
	remotes.syncState:fire(player, ...)
end)

-- Sends the initial state to a player upon request. This should fire when a
-- player joins the game.
remotes.requestState:connect(function(player)
	syncer:hydrate(player)
end)
```

#### Parameters

-   `options`: An object to configure sync behavior.

    -   `atoms`: A dictionary of the atoms to sync. The keys should match the keys on the client.

    -   **optional** `interval`: The interval at which to batch state updates to clients. Defaults to `0`, meaning updates are batched every frame.

    -   **optional** `preserveHistory`: Whether to sync an exhaustive history of changes made to the atoms since the last sync event. If `true`, the server sends multiple payloads instead of one. Defaults to `false` for performance.

    -   **optional** `autoSerialize`: Whether to apply validation and workarounds to certain [remote argument limitations](https://create.roblox.com/docs/scripting/events/remote#table-indexing). Defaults to `true`, but you should set it to `false` if you serialize remote arguments (i.e. if you use [ByteNet](https://github.com/ffrostfall/ByteNet) or [Zap](https://github.com/red-blox/zap)).

> [!NOTE]
> Charm sends table updates in the form of partial tables, so arrays will contain `nil` values, which has undefined behavior in remotes without serialization.
>
> Charm's default `autoSerialize` behavior fixes this, but it can interfere with custom serialization. Disable this option if you use a network library that serializes remote event arguments.

#### Returns

`server` returns an object with the following methods:

-   `syncer:connect(callback)`: Registers a callback to send state updates to clients. The callback will receive the player and the payload(s) to send, and should fire a remote event. The payload is read-only, so any changes should be applied to a copy of the payload.

-   `syncer:hydrate(player)`: Sends the player a full state update for all synced atoms.

#### Caveats

-   **Do not use values that cannot be sent over remotes** in your shared atoms. This includes functions, threads, and non-string keys in dictionaries. [Read more about argument limitations in remotes.](https://create.roblox.com/docs/scripting/events/remote#argument-limitations)

-   **By default, Charm omits the individual changes made to atoms** between sync events (i.e. a `counterAtom` set to `1` and then `2` will only send the final state of `2`). If you need to preserve a history of changes, set `preserveHistory` to `true`.

-   **Charm does not handle network communication.** Use remote events or a network library to send sync payloads - and remember to set `autoSerialize` accordingly!

---

### `client(options)`

Call `client` to create a client sync object. This synchronizes the client's atoms with the server's state by merging partial patches sent by the server into each atom.

```luau
local syncer = CharmSync.client({
	atoms = atomsToSync, -- A dictionary of the atoms to sync, matching the server's
	ignoreUnhydrated = true, -- Whether to ignore state updates before the initial update
})

-- Applies state updates from the server to the client's atoms.
-- Data deserialization can be done here.
remotes.syncState:connect(function(...)
	syncer:sync(...)
end)

-- Requests the initial state from the server when the client joins the game.
-- Before this runs, the client uses the atoms' default values.
remotes.requestState:fire()
```

#### Parameters

-   `options`: An object to configure sync behavior.

    -   `atoms`: A dictionary of the atoms to sync. The keys should match the keys on the server.

    -   **optional** `ignoreUnhydrated`: Whether to ignore state updates before setting the initial state. Defaults to `true`.

#### Returns

`client` returns an object with the following methods:

-   `syncer:sync(...payloads)` applies a state update from the server.

#### Caveats

-   **Charm does not handle network communication.** Use remote events or a network library to receive sync payloads. This includes requesting the initial state, which is implemented via `requestState` in the example above.

---

### `isNone(value)`

Call `isNone` to check if a value is `None`. Charm's partial state patches omit values that did not change between sync events, so to mark keys for deletion, Charm uses the `None` marker.

This function can be used to check whether a value is about to be removed from an atom.

```luau
local syncer = CharmSync.server({ atoms = atomsToSync })

syncer:connect(function(player, payload)
	if
		payload.type === "patch"
		and payload.data.todosAtom
		and CharmSync.isNone(payload.data.todosAtom.eggs)
	then
		-- 'eggs' will be removed from the client's todo list
	end
	remotes.syncState.fire(player, payload)
end)
```

#### Parameters

-   `value`: Any value. If the value is `None`, `isNone` will return `true`.

#### Returns

`isNone` returns a boolean.

---

## 🚀 Examples

### Counter atom

```luau
local counterAtom = atom(0)

-- Create a selector that returns double the counter value
local function doubleCounter()
	return counterAtom() * 2
end

-- Runs after counterAtom is updated and prints double the new value
subscribe(doubleCounter, function(value)
	print(value)
end)

counterAtom(1) --> 2
counterAtom(function(count)
	return count + 1
end) --> 4
```

### React component

```luau
local counter = require(script.Parent.counter)
local counterAtom = counter.counterAtom
local incrementCounter = counter.incrementCounter

local function Counter()
	local count = useAtom(counterAtom)

	return React.createElement("TextButton", {
		[React.Event.Activated] = incrementCounter,
		Text = `Count: {count}`,
		Size = UDim2.new(0, 100, 0, 50),
	})
end
```

### Vide component

```luau
local counter = require(script.Parent.counter)
local counterAtom = counter.counterAtom
local incrementCounter = counter.incrementCounter

local function Counter()
	local count = useAtom(counterAtom)

	return create "TextButton" {
		Activated = incrementCounter,
		Text = function()
			return `Count: {count()}`
		end,
		Size = UDim2.new(0, 100, 0, 50),
	}
end
```

### Server-client sync

Charm is designed for both client and server use, but there are often cases where the client needs to reference state that lives on the server. The CharmSync package provides a way to synchronize atoms between the server and its clients using remote events.

Start by creating a set of atoms to sync between the server and clients. Export these atoms from a module to be shared between the server and client:

```luau
-- atoms.luau
local counter = require(script.Parent.counter)
local todos = require(script.Parent.todos)

return {
	counterAtom = counter.counterAtom,
	todosAtom = todos.todosAtom,
}
```

Then, on the server, create a server sync object and pass in the atoms to sync. Use remote events to broadcast state updates and send initial state to clients upon request.

> [!NOTE]
> If `preserveHistory` is `true`, the server will send multiple payloads to the client, so the callback passed to `connect` should accept a variadic `...payloads` parameter. Otherwise, you only need to handle a single `payload` parameter.

```luau
-- sync.server.luau
local atoms = require(script.Parent.atoms)

local syncer = CharmSync.server({ atoms = atoms })

-- Sends state updates to clients when a synced atom changes.
-- Omitting sensitive information and data serialization can be done here.
syncer:connect(function(player, payload)
	remotes.syncState.fire(player, payload)
end)

-- Sends the initial state to a player upon request. This should fire when a
-- player joins the game.
remotes.requestState:connect(function(player)
	syncer:hydrate(player)
end)
```

Finally, on the client, create a client sync object and use it to apply incoming state changes.

```luau
-- sync.client.luau
local atoms = require(script.Parent.atoms)

local syncer = CharmSync.client({ atoms = atoms })

-- Applies state updates from the server to the client's atoms.
remotes.syncState:connect(function(payload)
	syncer:sync(payload)
end)

-- Requests the initial state from the server when the client joins the game.
-- Before this runs, the client uses the atoms' default values.
remotes.requestState:fire()
```

---

<p align="center">
Charm is released under the <a href="LICENSE.md">MIT License</a>.
</p>

<div align="center">

[![MIT License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE.md)

</div>
