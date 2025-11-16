<p align="center">
  <p align="center">
	<img width="150" height="150" src="https://raw.githubusercontent.com/littensy/charm/main/assets/logo.png" alt="Logo">
  </p>
  <h1 align="center"><b>Charm</b></h1>
  <p align="center">
    Manage state with reactive signals
    <br />
    <a href="https://npmjs.com/package/@rbxts/charm"><strong>npm package →</strong></a>
  </p>
</p>

<div align="center">

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/littensy/charm/ci.yml?style=for-the-badge&branch=main&logo=github)
[![NPM Version](https://img.shields.io/npm/v/@rbxts/charm.svg?style=for-the-badge&logo=npm)](https://www.npmjs.com/package/@rbxts/charm)
[![GitHub License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE.md)

</div>

**Charm** is a Roblox state management library inspired by the [reactive signals](https://preactjs.com/blog/introducing-signals/) from libraries like Preact and Solid. It's built on [alien-signals](https://github.com/stackblitz/alien-signals), modified for a wide range of use cases: from rendering user interfaces to handling game logic.

**Charm works under a few core principles.**

- Manage state with reactive signals: state containers that hold a value
- React to state updates: reading a signal automatically subscribes to it
- Combine multiple signals: derive new values from existing state that stay up-to-date
- Fine-grained reactivity: make targeted updates in response to specific changes in the state
- Data should be immutable: values are compared directly (`==`) to optimize change detection

**Want to learn more about signals?**

- https://preactjs.com/blog/introducing-signals
- https://docs.solidjs.com/advanced-concepts/fine-grained-reactivity
- https://angular.dev/guide/signals

<details>
<summary><b>Table of Contents</b></summary>

- [Installation](#installation)
- [Reference](#reference)
    - [`signal(initialValue, equals?)`](#signalinitialvalue-equals)
    - [`computed(getter)`](#computedgetter)
    - [`effect(callback)`](#effectcallback)
    - [`untracked(callback)`](#untrackedcallback)
    - [`peek(callback)`](#peekcallback)
    - [`batch(callback)`](#batchcallback)
    - [`effectScope(callback)`](#effectscopecallback)
    - [`listen(getter, callback)`](#listengetter-callback)
    - [`subscribe(getter, callback)`](#subscribegetter-callback)
    - [`observe(getter, callback)`](#observegetter-callback)
    - [`mapped(getter, mapper)`](#mappedgetter-mapper)
    - [`onCleanup(callback, failSilently?)`](#oncleanupcallback-failsilently)
    - [`atom(initialValue, equals?)`](#atominitialvalue-equals)
    - [`recursive()`](#recursive)
        - [`trigger(callback)`](#triggercallback)
        - [`flags`](#flags)
- [Client-Server Sync](#client-server-sync)
    - [Installation](#installation-1)
    - [Quick Start](#quick-start)
    - [Server API](#config)
    - [Client API](#clientaddsignalssetters)
    - [Sync Caveats](#sync-caveats)
- [Migration](#migration)
- [Examples](#examples)

</details>

## At a Glance

```luau
local getTodos, setTodos = signal({} :: { [number]: string })
local getQuery, setQuery = signal("")

observe(getTodos, function(todo, index)
	local instance = Instance.new("TextLabel")

	local getText = computed(function(prevText)
		return getTodos()[index] or prevText
	end)

	effect(function()
		instance.Text = getText()
		instance.Visible = getText():match(getQuery()) ~= nil
	end)

	instance.LayoutOrder = index
	instance.Size = UDim2.new(1, 0, 0, 40)
	instance.Parent = screenGui

	return function()
		instance:Destroy()
	end
end)

setTodos({ "Buy milk", "Buy eggs", "Play Roblox" })
setQuery("^Buy")
```

<details>
<summary>Explain code</summary>

```luau
local getTodos, setTodos = signal({} :: { [number]: string })
local getQuery, setQuery = signal("")

-- Create a text label when an item is added to the list
observe(getTodos, function(todo, index)
	local instance = Instance.new("TextLabel")

	-- Create a computed signal that stores the current text, or the previous
	-- value if the item was removed
	local getText = computed(function(prevText)
		return getTodos()[index] or prevText
	end)

	-- Set properties when the text or query updates
	effect(function()
		instance.Text = getText()
		instance.Visible = getText():match(getQuery()) ~= nil
	end)

	instance.LayoutOrder = index
	instance.Size = UDim2.new(1, 0, 0, 40)
	instance.Parent = screenGui

	-- Destroy the instance when this item is removed
	return function()
		instance:Destroy()
	end
end)

-- Add items to the todo list
setTodos({ "Buy milk", "Buy eggs", "Play Roblox" })
-- Filter for items starting with "Buy"
setQuery("^Buy")
```

</details>

## Installation

```sh
npm install @rbxts/charm
yarn add @rbxts/charm
pnpm add @rbxts/charm
```

```toml
[dependencies]
Charm = "littensy/charm@VERSION"
```

---

## Reference

### `signal(initialValue, equals?)`

Signals are the core of reactivity in Charm. The `signal` function creates a reactive signal that acts as a container for a value. It returns a function to access the value, and another to update the value.

```luau
local getCounter, setCounter = signal(0)

print(getCounter()) -- 0
setCounter(1)
setCounter(function(count)
	return count + 1
end)
```

Accessing the signal's value in an effect or computed signal will subscribe to it as a dependency. Changing the value will immediately notify every effect and computed signal that depends on the signal, ensuring all of your state is correct and up-to-date.

You can also pass a custom equality function to only update the signal if the equality function returns `false`:

```luau
local getMax, setMax = signal(0, function(current, incoming)
	return incoming <= current
end)

setMax(1) -- 1
setMax(2) -- 2
setMax(-1) -- 2
```

> [!NOTE]
> Looking for atoms? You can still use [`atom()`](#atominitialvalue-equals) to create a signal with a combined getter and setter.

---

### `computed(getter)`

The `computed` function creates a new signal with a value derived from multiple signals. The computed signal can be reacted to like a normal signal, and it returns the getter function's last return value.

The computed signal will subscribe to signals accessed by the getter and track them as dependencies. Changes to these dependencies will re-execute the getter, and if it returns a new value, then the computed signal is updated to that value.

```luau
local getName, setName = signal("John")
local getSurname, setSurname = signal("Doe")
local getFullName = computed(function()
	return `{getName()} {getSurname()}`
end)

print(getFullName()) -- "John Doe"
setName("Jane")
print(getFullName()) -- "Jane Doe"
```

The getter function also receives the previous state (or `nil` if running for the first time). You can use this for more complex state:

```luau
local getCounter, setCounter = signal(10)
local getMax = computed(function(prevMax)
	return math.max(getCounter(), prevMax or 0)
end)

print(getMax()) -- 10
setCounter(5)
print(getMax()) -- 10
```

Computed signals are updated lazily, meaning the getter will only re-execute once the computed signal is called _and_ if a dependency updated since the last call.

---

### `effect(callback)`

Effects are fundamental to reactivity, allowing you to react to signal updates. The `effect` function subscribes to signals accessed by the effect callback, and when a dependency updates, the callback will re-execute.

```luau
local getCounter, setCounter = signal(0)

-- Count is 0
effect(function()
	print(`Count is {getCounter()}`)
end)

setCounter(1) -- Count is 1
```

You can also return a cleanup function that will run once, either before the effect re-runs or when the effect is disposed:

```luau
local getCounter, setCounter = signal(0)

local dispose = effect(function()
	local count = getCounter()
	return function()
		print(`Cleanup {count}`)
	end
end)

setCounter(1) -- Cleanup 0
dispose() -- Cleanup 1
```

Effects can be nested and they will clean up automatically when the parent effect re-runs or gets disposed. This means you don't have to manually clean up inner effects, and this applies to functions like `subscribe()` and `observe()`.

```luau
local getCounter, setCounter = signal(0)

effect(function()
	print(`Outer: {getCounter()}`)
	effect(function()
		print(`Inner: {getcounter()}`)
	end)
end)

setCounter(1) -- Outer: 1, Inner: 1
setCounter(2) -- Outer: 2, Inner: 2
```

> [!NOTE]
> To run code that is "detached" from the parent effect or scope, use `untracked()` or a detached effect scope. If you suspect that the new nested effect behavior is causing issues with migration, try disabling the `flags.trackInnerEffects` flag to assist with debugging.

---

### `untracked(callback)`

In case you want to read signals but don't want to subscribe to them, you can use `untracked()` to essentially run code _outside_ the current effect, preventing signals and effects in the callback from being tracked.

```luau
local getTracked, setTracked = signal(0)
local getUntracked, setUntracked = signal(0)

-- Tracked: 0, Untracked: 0
effect(function()
	print(`Tracked: {getTracked()}, Untracked: {untracked(getUntracked)}`)
end)

setTracked(1) -- Tracked: 1, Untracked: 0
setUntracked(1) -- No output
setTracked(2) -- Tracked: 2, Untracked: 1
```

Because `untracked()` executes the callback outside the current effect, nested effects created in the callback do not get tracked by the parent effect:

```luau
local stopEffect
local stopScope = effectScope(function()
	untracked(function()
		stopEffect = effect(function()
			return function()
				print("Cleaned up untracked effect")
			end
		end)
	end)
end)

stopScope() -- No output, the scope did not track the effect
stopEffect() -- Cleaned up untracked effect
```

---

### `peek(callback)`

Similar to `untracked()`, but does not prevent the parent effect from tracking nested effects created in the callback. If your callback reads a signal and creates effects, only the signals get untracked.

```luau
local getCounter, setCounter = signal(0)

-- Count is 0
local disposeOuter = effect(function()
	print(`Count is {peek(getCounter)}`)
end)

setCounter(1) -- No output; count was accessed in peek()
```

---

### `batch(callback)`

Combines multiple signal updates made by the callback into a single commit that triggers effects once the callback completes.

```luau
local getName, setName = signal("John")
local getSurname, setSurname = signal("Doe")

effect(function()
	print(`Full name: {getName()} {getSurname()}`)
end)

-- Combines both writes into a single update.
-- Once the callback completes, outputs "Full name: Foo Bar"
batch(function()
	setName("Foo")
	setSurname("Bar")
end)
```

---

### `effectScope(callback)`

Scopes allow you to dispose multiple effects at once. The `effectScope` function creates an effect with no dependencies, and effects created inside the callback clean up when the effect scope disposes.

```luau
local getCounter, setCounter = signal(0)

local dispose = effectScope(function()
	effect(function()
		print(`Count 1 is {getCounter()}`)
	end)
	effect(function()
		print(`Count 2 is {getCounter()}`)
	end)
end)

setCounter(1) -- Count 1 is 1, Count 2 is 1
dispose()
setCounter(2) -- No output; effects got disposed
```

Similar to `effect()`, the callback can return a cleanup function that runs when the effect scope is disposed.

---

### `listen(getter, callback)`

The `listen` function creates an effect that only subscribes to the signals accessed by `getter`. Signals accessed by the callback will not be subscribed to, avoiding accidental subscriptions when you want to run side effects.

The callback also receives the previous value, or `nil` when running for the first time.

```luau
local getCounter, setCounter = signal(0)

-- Count is 0 (was nil)
listen(getCounter, function(count, prevCount)
	print(`Count is {count} (was {prevCount})`)
end)

setCounter(1) -- Count is 1 (was 0)
```

Note that nested effects can be created inside `listen`, and they will clean up automatically when the listener re-runs or gets disposed.

---

### `subscribe(getter, callback)`

The `subscribe` function is identical to `listen()`, but the callback does not run initially. The callback only runs when the value returned by the getter function changes.

```luau
local getCounter, setCounter = signal(0)

-- Does not output anything initially
subscribe(getCounter, function(count, prevCount)
	print(`Count is {count} (was {prevCount})`)
end)

setCounter(1) -- Count is 1 (was 0)
```

Note that nested effects can be created inside `subscribe`, and they will clean up automatically when the subscription re-runs or gets disposed.

---

### `observe(getter, callback)`

[Observers](https://sleitnick.github.io/RbxObservers/docs/observer-pattern) allow you to track the lifetime of a given state. The `observe` function executes the callback for every unique key added to a table, and disposes the callback when that key is removed.

```luau
local getItems, setItems = signal({ a = 0, b = 0 })

-- Added a, Added b
observe(getItems, function(value, key)
	print(`Added {key}`)
	return function()
		print(`Removed {key}`)
	end
end)

setItems({ a = 0, c = 0 }) -- Removed b, Added c
```

The callback runs in an effect scope, so effects created in the callback will be disposed when the key is removed:

```luau
local getItems, setItems = signal({ a = 0, b = 0 })

local dispose = observe(getItems, function(value, key)
	local getValue = computed(function(prevValue)
		return getItems()[key] or prevValue
	end)

	effect(function()
		local value = getValue()
		print(`{key} = {value}`)
		return function()
			print(`Cleanup {key} = {value}`)
		end
	end)
end)

setItems({ a = 1, b = 0 }) -- Cleanup a = 0, a = 1
setItems({ a = 1 }) -- Cleanup b = 0
dispose() -- Cleanup a = 1
```

---

### `mapped(getter, mapper)`

The `mapped` function iterates over every key in a table and uses the mapper to assign them to a new key and value. The result is returned as a read-only signal containing the new keys and values. When a key's value changes, or a new key is added to the table, the mapper is called for that key and its current value.

The first value returned by the mapper is used as the new value:

```luau
local getList, setList = signal({ "a", "b", "c" })

local getUppercase = mapped(getList, function(value)
	return string.upper(value)
end)

print(getUppercase()) -- { "A", "B", "C" }
```

If the mapper returns two values, the second value is used as the new key:

```luau
local getList, setList = signal({ "a", "b", "c" })

local getSwapped = mapped(getList, function(value, key)
	return key, value
end)

print(getSwapped()) -- { a = 1, b = 2, c = 3 }
```

---

### `onCleanup(callback, failSilently?)`

The `onCleanup` function binds the callback to the currently running effect or effect scope. Multiple cleanup functions can be bound to the same effect.

If there is no active effect, a warning is logged, unless `failSilently` is set to `true`.

```luau
local dispose = effectScope(function()
	onCleanup(function()
		print("Cleaned up")
	end)
end)

dispose() -- Cleaned up
```

---

### `atom(initialValue, equals?)`

The `atom` function creates a new reactive signal and returns a single function that acts as both a getter and setter.

If the atom is called with 0 arguments, the atom returns the current value and subscribes to the signal. Otherwise, when called with 1 or more arguments, the atom will update the signal's value.

```luau
local counter = atom(0)

print(counter()) -- 0
counter(1)
counter(function(count)
	return count + 1
end)
```

You can also pass a custom equality function to only update the signal if the new value is _not_ equal to the current value:

```luau
local max = atom(0, function(current, incoming)
	return incoming <= current
end)

max(1) -- 1
max(-1) -- 1
```

---

### `recursive()`

By design, Charm's reactive system [does not allow recursion](https://github.com/stackblitz/alien-signals/issues/90#issuecomment-3489711800) in effects or computed signals. In case you need to opt out of recursion checks for an effect, you can call `recursive()` at the top of the effect callback:

```luau
local getCounter, setCounter = signal(0)

effect(function()
	recursive()
	print(getCounter())
	setCounter(function(count)
		return math.min(count + 1, 3)
	end)
end)

-- Output: 0, 1, 2, 3
```

---

### `trigger(callback)`

The `trigger()` function allows you to manually trigger updates for downstream dependencies when you've directly mutated a signal's value without using the signal setter:

```luau
local array = signal({} :: { number })
local length = computed(function()
	return #array()
end)

print(length()) -- 0

-- Direct mutation doesn't automatically trigger updates
table.insert(array(), 1)
print(length()) -- Still 0

-- Manually trigger updates
trigger(array)
print(length()) -- 1
```

You can also trigger multiple signals at once:

```luau
local src1 = signal({} :: { number })
local src2 = signal({} :: { number })
local total = computed(function()
	return #src1() + #src2()
end)

table.insert(src1(), 1)
table.insert(src2(), 2)

trigger(function()
  src1()
  src2()
end)

print(total()) -- 2
```

---

### `flags`

Charm exposes the following global flags to customize behavior:

| Flag              | Default        | Description                                                                                                                                            |
| ----------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| strict            | `true`/`false` | Enforces synchronous, non-yielding behavior in signals, effects, and other critical code.                                                              |
| frozen            | `true`/`false` | Enforces data immutability by deep-freezing tables passed to signals.                                                                                  |
| trackInnerEffects | `true`         | Whether nested effects should be tracked and cleaned up when the parent effect re-runs. This should only be disabled to debug issues during migration. |

The `strict` and `frozen` flags are automatically enabled in Roblox Studio. More accurately, they are enabled for the Luau optimization levels `O1` and lower.

---

## Client-Server Sync

### Installation

```sh
npm install @rbxts/charm-sync
yarn add @rbxts/charm-sync
pnpm add @rbxts/charm-sync
```

```toml
[dependencies]
CharmSync = "littensy/charm-sync@VERSION"
```

### Quick Start

Start by specifying the signals that the server should sync to clients. For this example, we'll use the first and last name signals:

```luau
-- nameStore
local getName, setName = signal("John")
local getSurname, setSurname = signal("Doe")

return {
	getName = getName,
	setName = setName,
	getSurname = getSurname,
	setSurname = setSurname,
}
```

When a player joins on the server, call `server.addSignalsToClient` with the keyed signals that the client should receive updates for. Once they leave, call `server.removeClient` to unsubscribe them from all updates.

Then, use `server.connect` to specify how state updates should be sent to each client. Pass a callback function that fires a remote with the given target player and the state updates they subscribed to.

```luau
local function onPlayerAdded(player: Player)
	-- Add signal getters, computed signals, or atoms
	server.addSignalsToClient(player, {
		name = nameStore.getName,
		surname = nameStore.getSurname,
	})
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	server.removeClient(player)
end)

server.connect(function(player, updates)
	-- Customize how you send state updates to clients
	syncEvent:FireClient(player, updates)
end)
```

> [!NOTE]
> On the server, make sure each key corresponds to the same signal across all players. If two players subscribe to the same key, but were given different signals, Charm will output a warning.

To sync the client with the server's state, call `client.addSignals` with a table of writable signals (setter functions or atoms) whose keys match their server counterparts.

After the client receives updates from the server, call `client.patch` to patch the client's signals with the incoming state updates.

```luau
-- Add signal setters or atoms
client.addSignals({
	name = nameStore.setName,
	surname = nameStore.setSurname,
})

-- Update client signals when receiving updates from the server
syncEvent.OnClientEvent:Connect(function(updates)
	client.patch(updates)
end)
```

---

### `config`

A configuration table that customizes the behavior of Charm Sync on the server.

| Option          | Default | Description                                                                                                                                                                                                                                                           |
| --------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| interval        | `0`     | The frequency at which the server will send patches to the client, in seconds. A value of `0` sends updates on the next frame. Set to a negative value to disable the interval.                                                                                       |
| preserveHistory | `false` | Whether to preserve a full history of state changes since the last sync, at the cost of performance. This is useful if you need to replicate each individual change that occurs between sync events.                                                                  |
| fixArrays       | `true`  | When `true`, Charm will attempt to work around Roblox remote event limitations regarding array patches. Disable this if your networking library serializes remote arguments (Zap, ByteNet, etc.).                                                                     |
| validatePatches | `true`  | When `true`, and both `fixArrays` and strict mode are enabled, synced values containing unsafe sparse arrays or mixed tables will throw an error. See the [remote argument limitations](https://create.roblox.com/docs/scripting/events/remote#argument-limitations). |

---

### `server.addSignalsToClient(client, getters)`

The `addSignalsToClient` function subscribes a client to updates in the given signals. When an update occurs, the client will receive a state patch of only the values that changed.

You can pass signal getter functions, computed signals, and atoms in the `getters` table. This function can also be called multiple times on the same client to subscribe to new signals.

```luau
Players.PlayerAdded:Connect(function(player)
	server.addSignalsToClient(player, {
		name = nameStore.getName,
		surname = nameStore.getSurname,
	})
end)
```

You're also allowed to create new signals to sync to specific players, as long as the key is also unique to that player:

```luau
server.addSignalsToClient(player, {
	[`data-{player.UserId}`] = computed(function()
		return getPlayerData(player.UserId)
	end),
})
```

---

### `server.removeSignalsFromClient(client, ...keys)`

The `removeSignalsFromClient` function unsubscribes the client from a list of keys that were previously subscribed to via `addSignalsToClient`.

```luau
server.addSignalsToClient(player, {
	surname = nameStore.getSurname,
})

server.removeSignalsFromClient(player, "surname")
```

---

### `server.removeClient(client)`

The `removeClient` function unsubscribes a client from receiving all state updates from the server. You should call this function when a player leaves the game.

```luau
Players.PlayerAdded:Connect(function(player)
	server.addSignalsToClient(player, signals)
end)

Players.PlayerRemoving:Connect(function(player)
	server.removeClient(player)
end)
```

---

### `server.connect(onSync)`

Binds a callback to run when sending state updates a client. Scheduled updates will be sent periodically at the interval specified in [`config.interval`](#config).

When a synced signal updates, the `onSync` function is scheduled to run for each client subscribed to that signal on the next sync event.

```luau
server.connect(function(player, updates)
	syncEvent:FireServer(player, updates)
end)
```

---

### `server.disconnect()`

Stops syncing state updates to clients at the automatic interval. This doesn't unbind the last callback, so you can still manually trigger sync events after calling this function by calling `server.flush()`.

```luau
server.connect(function(player, updates)
	syncEvent:FireServer(player, updates)
end)

-- Stops calling the function at the automatic interval
server.disconnect()

-- Flushing still sends pending updates
server.flush()
```

---

### `client.addSignals(setters)`

Subscribes the given writable signals to the states with the corresponding keys on the server. When the server sends updates, the functions associated with each key in the state will be called with the patched values.

You can pass either writable signals or atoms to this function:

```luau
client.addSignals({
	name = nameStore.setName,
	surname = nameStore.setSurname,
})
```

---

### `client.removeSignals(...keys)`

Unsubscribes from each signal with the corresponding keys. The signals will retain their current values, but will no longer receive updates from the server.

```luau
client.addSignals({
	name = nameStore.setName,
})

client.removeSignals("name")
```

---

### `client.patch(updates)`

The `patch` function patches the client's state with the updates sent from the server. The initial update sent by the server will be the full state, and later updates will only include the values that changed.

You should call `patch` when receiving updates from the server from a remote event:

```luau
client.addSignals({
	name = nameStore.setName,
	surname = nameStore.setSurname,
})

syncEvent.OnClientEvent:Connect(function(updates)
	client.patch(updates)
end)
```

---

### Sync Caveats

Charm Sync will only send clients the differences between the current state and the previously-synced state, which is a practice called _delta compression_. In this case, tables are recursively scanned for changes, and unchanged properties are omitted by setting them to `nil`.

But it's hard to differentiate between an unchanged value and a removed value, as both cases are represented by `nil`. We chose to address this by representing deleted values with a special `None` symbol denoted by `{ __none = "__none" }`.

This means nilable values can be represented as `None`, and code working with update payloads (usually for remote argument serialization) should account for nilable values possibly being sent as `None` in the payload.

---

## Migration

Charm v0.11 introduces _a lot_ of breaking changes, so below are some tips that might help you migrate from an older version.

<details>
<summary><b>Terminology changes</b></summary>

- Signal: A state container with one function to get the state, and another to update it
- Atom: A signal with the getter and setter combined into one function
- Effect: Main way to react to state changes
- `subscribe(getter, callback)`: Creates an effect that only subscribes to signals accessed in the getter

</details>

**What to look out for:**

1. Address all of the type errors introduced in your project after updating Charm. Most of them are caused by changes like:
    - The second arguments of `atom()` changed from an `options` table to an equality function
    - Removed the second argument of `computed()` (you can do your own equality checks now)
    - Removed the cleanup argument in effect callbacks (`effect(function(cleanup) end)`)

2. If you use Charm Sync, you'll have to rewrite a lot of your sync code. Fortunately, most of the changes should make your code _less_ complicated:
    - You can now sync signals per-client, including computed signals. You shouldn't have to modify sync payloads to filter data anymore.
    - Instead of creating client/server syncers, these modules now act like singletons. Sync APIs are called directly through `CharmSync.client`/`server`.
    - [Read the updated docs for syncing state →](#client-server-sync)

3. The [`strict` and `frozen` flags](#flags) are automatically enabled in Roblox Studio, so unsafe Charm code will start throwing errors if you didn't use the old `__DEV__` flag. The flags have the following behavior:
    - `strict`: Yielding in effects, signals, and other critical Charm functions will throw an error
    - `frozen`: Tables passed to signals are deeply frozen to strictly enforce data immutability and prevent accidental mutations

4. Nested effects automatically clean up when the parent effect re-runs or gets disposed. In other words, all effects created during the execution of another effect will be added as a "child" and clean up with the parent effect. This might cause issues in code that relied on the old behavior, where effects were detached from the parent.
    - This feature applies to all reaction APIs, including the listener function in `subscribe()` and the observer function in `observe()`.
    - Effects that should not be tracked by a parent effect/scope should be wrapped in [`untracked()`](#untrackedcallback).
    - This feature can introduce runtime bugs in migrated code. If you suspect this to be the cause, to help identify the issue, you can disable this feature by setting [`flags.trackInnerEffects`](#flags) to `false`.

> [!NOTE]
> An example of nested effects causing a bug is an old implementation of [`VideCharm.useAtom`](./packages/vide-charm/src/init.luau) that did not wrap the source update in `untracked()`. Because Vide effects run immediately after a source updates, Vide will notify components during the execution of the Charm effect in `useAtom`.
>
> This meant effects created as a side effect of a source update would implicitly get added as a child of the `useAtom` effect, and they could get disposed at the wrong time and desync UI.

5. Recursion is now disallowed in effects and computed signals by default. This change may introduce bugs in code relying on the old behavior.
    - Recursive checks are opt-out. You can allow recursion for a specific effect by calling [`recursive()`](#recursive) at the top of the effect callback.

6. Consider refactoring your code to use some new quality-of-life features. Many of these are made possible thanks to [alien-signals](https://github.com/stackblitz/alien-signals)!
    - Added [`signal()`](#signalinitialvalue-equals) to make reads and writes more explicit
    - Added [`listen()`](#listengetter-callback) to create a subscription that runs once immediately
    - Added [`effectScope()`](#effectscopecallback) for collecting and cleaning up multiple effects at once
    - Added [`onCleanup()`](#oncleanupcallback-failsilently) to bind a cleanup function to the active effect
    - Added [`trigger()`](#triggercallback) to trigger updates for table mutations
    - The [`computed()`](#computedgetter) callback now gets called with the previous computed value
    - Optimized `computed()` to use lazy evaluation instead of eager updates
    - Optimized `mapped()` to only map values that changed in the original table

---

## Examples

Check out this simple [example project →](https://github.com/littensy/charm-example)

### React Counter

```luau
local getCounter, setCounter = signal(0)

local function Counter()
	local count = useSignalState(getCounter)

	return React.createElement("TextButton", {
		[React.Event.Activated] = function()
			setCounter(count + 1)
		end,
		Text = `Count: {count}`,
		Size = UDim2.fromOffset(100, 50),
	})
end
```

### Vide Counter

```luau
local getCounter, setCounter = signal(0)

local function Counter()
	local count = useSignalState(getCounter)

	return create "TextButton" {
		Activated = function()
			setCounter(function(count)
				return count + 1
			end)
		end,
		Text = function()
			return `Count: {count()}`
		end,
		Size = UDim2.fromOffset(100, 50),
	}
end
```

---

<p align="center">
Charm is released under the <a href="LICENSE.md">MIT License</a>.
</p>

<div align="center">

[![MIT License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE.md)

</div>
