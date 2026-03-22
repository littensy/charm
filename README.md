<p align="center">
  <p align="center">
	<img width="150" height="150" src="https://raw.githubusercontent.com/littensy/charm/main/assets/logo.png" alt="Logo">
  </p>
  <h1 align="center"><b>Charm</b></h1>
  <p align="center">
    Fine-grained reactivity for Roblox
    <br />
    <a href="https://npmjs.com/package/@rbxts/charm"><strong>npm package →</strong></a>
  </p>
</p>

<div align="center">

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/littensy/charm/ci.yml?style=for-the-badge&branch=main&logo=github)
[![NPM Version](https://img.shields.io/npm/v/@rbxts/charm.svg?style=for-the-badge&logo=npm)](https://www.npmjs.com/package/@rbxts/charm)
[![GitHub License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE)

</div>

Charm is a state management library based on [fine-grained reactivity](https://dev.to/ryansolid/a-hands-on-introduction-to-fine-grained-reactivity-3ndf). Connect behavior to data with reactive signals, ensuring games stay up-to-date with their underlying data while eliminating the need for manual updates.

**Build game state from simple building blocks:**

- Store state in [signals](#signalinitialvalue-equals): state containers that hold a value
- React to state changes with [effects](#effectcallback): re-run code when a dependency updates
- Derive values from state with [computed signals](#computedgetter): memoized functions with dependency tracking

**Want to learn more about signals?**

- https://dev.to/ryansolid/a-hands-on-introduction-to-fine-grained-reactivity-3ndf
- https://preactjs.com/blog/introducing-signals
- https://docs.solidjs.com/advanced-concepts/fine-grained-reactivity
- https://angular.dev/guide/signals

[Migrating from an older version of Charm?](#migration)

<details>
<summary><b>Table of Contents</b></summary>

- [Installation](#installation)
- [Reference](#reference)
    - [`signal(initialValue, equals?)`](#signalinitialvalue-equals)
    - [`computed(getter)`](#computedgetter)
    - [`effect(callback)`](#effectcallback)
    - [Nested effects](#nested-effects)
    - [`effectScope(callback)`](#effectscopecallback)
    - [`listen(getter, callback)`](#listengetter-callback)
    - [Getter functions](#getter-functions)
    - [`observe(getter, callback)`](#observegetter-callback)
    - [`subscribe(getter, callback)`](#subscribegetter-callback)
    - [`untracked(callback)`](#untrackedcallback)
    - [`batch(callback)`](#batchcallback)
    - [`mapped(getter, mapper)`](#mappedgetter-mapper)
    - [`onCleanup(callback, failSilently?)`](#oncleanupcallback-failsilently)
    - [`atom(initialValue, equals?)`](#atominitialvalue-equals)
    - [`trigger(callback)`](#triggercallback)
    - [`flags`](#flags)
- [Client-Server Sync](#client-server-sync)
    - [Installation](#installation-1)
    - [Quick Start](#quick-start)
    - [Server API](#config)
    - [Client API](#clientaddsignalssetters)
    - [Sync Caveats](#sync-caveats)
- [Deep Reactivity](#deep-reactivity)
    - [Installation](#installation-2)
    - [`reactive(initialValue)`](#reactiveinitialvalue)
    - [Mutation vs. update function](#mutation-vs-update-function)
    - [`toRaw(value)`](#torawvalue)
    - [`isReactive(value)`](#isreactivevalue)
- [Migration](#migration)
- [Examples](#examples)

</details>

## At a Glance

```luau
local getTodos, setTodos = signal({} :: { string })
local getQuery, setQuery = signal("")

observe(getTodos, function(todo: string, index: number)
	local instance = Instance.new("TextLabel")

	local getText = computed(function()
		return getTodos()[index] or ""
	end)

	effect(function()
		instance.Text = getText()
		instance.Visible = string.match(getText(), getQuery()) ~= nil
	end)

	instance.LayoutOrder = index
	instance.Size = UDim2.new(1, 0, 0, 40)
	instance.Parent = screenGui

	return function()
		instance:Destroy()
	end
end)

setTodos({ "Buy milk", "Buy eggs", "Play Roblox" })
setQuery("Buy")
```

<details>
<summary>Explain code</summary>

```luau
-- Declare state for a todo list and a search query
local getTodos, setTodos = signal({} :: { string })
local getQuery, setQuery = signal("")

-- Create a text label when an item is added to the list
observe(getTodos, function(todo, index)
	local instance = Instance.new("TextLabel")

	-- Create a memoized function that only re-runs effects when the todo list
	-- updates or the function returns new text
	local getText = computed(function()
		return getTodos()[index] or ""
	end)

	-- Update instance properties when the text or query updates
	effect(function()
		instance.Text = getText()
		instance.Visible = string.match(getText(), getQuery()) ~= nil
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
-- Filter for items containing "Buy"
setQuery("Buy")
```

</details>

## Installation

```sh
npm install @rbxts/charm
yarn add @rbxts/charm
pnpm add @rbxts/charm
```

```toml
# wally.toml
[dependencies]
Charm = "littensy/charm@VERSION"
```

---

## Reference

### `signal(initialValue, equals?)`

Signals are the core of reactivity in Charm. The `signal` function creates a reactive signal that acts as a container for a value. It returns a function to access the value, and another to update the value.

```luau
local getCounter, setCounter = signal(0)

setCounter(1)
setCounter(function(count)
	return count + 1
end)
print(getCounter()) -- 2
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
> Looking for atoms? You can still use [`atom()`](#atominitialvalue-equals) to create a signal with a unified getter and setter.

---

### `effect(callback)`

Effects are fundamental to reactivity, allowing you to react to signal updates. The `effect` function subscribes to signals accessed by the effect callback, and when a dependency updates, the callback will re-execute.

```luau
local getCounter, setCounter = signal(0)

effect(function()
	print(`Count is {getCounter()}`)
end) -- Count is 0

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

### Nested Effects

An effect is _nested_ if it was created during the execution of another effect. In Charm, when an effect with nested effects re-runs or gets cleaned up, the nested effects from the previous run are automatically cleaned up and re-created if needed. This prevents memory leaks and ensures that outer effects always run before their inner effects:

```luau
local getPrintCount, setPrintCount = signal(true)
local getCount, setCount = signal(1)

effect(function()
	if getPrintCount() then
		-- This inner effect is created when getPrintCount() is true
		effect(function()
			print(`Count is {getCount()}`)
		end)
	end
end) -- Count is 1

setCount(2) -- Count is 2

-- This re-runs the outer effect and cleans up old inner effects
setPrintCount(false)

setCount(3) -- No output
```

> [!NOTE]
> To run code that is "detached" from the parent effect or scope, use `untracked()` or a detached effect scope. If you suspect that the new nested effect behavior is causing issues with migration, try disabling the `flags.trackInnerEffects` flag to assist with debugging.

---

### `computed(getter)`

The `computed` function creates a read-only signal whose value is derived from other signals. The computed signal caches the getter function's last result, and the value is only re-computed if a dependency has updated since the last computation.

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

The getter function also receives the previous result (or `nil` during the initial run). You can use this for computed signals that depend on the previous result:

```luau
local getCounter, setCounter = signal(10)
local getMax = computed(function(prevMax)
	return math.max(getCounter(), prevMax or 0)
end)

print(getMax()) -- 10
setCounter(5)
print(getMax()) -- 10
```

---

### `effectScope(callback)`

Scopes allow you to dispose multiple effects at once. The `effectScope` function creates a scope that tracks inner effects, so effects created during the execution of the callback will clean up when the scope disposes.

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

listen(getCounter, function(count, prevCount)
	print(`Count is {count} (was {prevCount})`)
end) -- Count is 0 (was nil)

setCounter(1) -- Count is 1 (was 0)
```

Note that the listener callback runs in `untracked()`, so nested effects are not cleaned up.

### Getter functions

In most Charm APIs, you can also subscribe to getter functions that call one or more signals, and they will automatically be tracked:

```luau
local getCounter, setCounter = signal(0)

local function floorCounter()
	return math.floor(getCounter())
end

listen(floorCounter, function(count, prevCount)
	print(`Floor of count is {count} (was {prevCount})`)
end) -- Floor of count is 0 (was nil)

setCounter(0.5) -- Doesn't print anything, floor is still 0
setCounter(1) -- Floor of count is 1 (was 0)
```

---

### `observe(getter, callback)`

[Observers](https://sleitnick.github.io/RbxObservers/docs/observer-pattern) allow you to track the lifetime of a given state. The `observe` function executes the callback for every unique key added to a table, and disposes the callback when that key is removed.

```luau
local getItems, setItems = signal({ a = 0, b = 0 })

observe(getItems, function(value, key)
	print(`Added {key}`)
	return function()
		print(`Removed {key}`)
	end
end) -- Added a, Added b

setItems({ a = 0, c = 0 }) -- Removed b, Added c
```

The callback runs in an effect scope, so effects created in the callback will be disposed when the key is removed:

```luau
local getItems, setItems = signal({})

local dispose = observe(getItems, function(value, key)
	local getValue = computed(function(prevValue)
		return getItems()[key] or prevValue
	end)

	effect(function()
		local value = getValue()
		print(`Set {key} = {value}`)
		return function()
			print(`Cleanup {key} = {value}`)
		end
	end)
end)

setItems({ a = 0, b = 0 }) -- Set a = 0, Set b = 0
setItems({ a = 1, b = 0 }) -- Cleanup a = 0, Set a = 1
setItems({ a = 1 }) -- Cleanup b = 0
dispose() -- Cleanup a = 1
```

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

---

### `untracked(callback)`

In case you want to opt-out of dependency tracking in an effect, you can use `untracked()` to call a function _outside_ the current scope, preventing signals and effects in the function from being tracked.

```luau
local getTracked, setTracked = signal(0)
local getUntracked, setUntracked = signal(0)

effect(function()
	print(`Tracked: {getTracked()}, Untracked: {untracked(getUntracked)}`)
end) -- Tracked: 0, Untracked: 0

setTracked(1) -- Tracked: 1, Untracked: 0
setUntracked(1) -- No output
setTracked(2) -- Tracked: 2, Untracked: 1
```

Because `untracked()` executes the callback outside the current effect, nested effects created during the execution of the callback will not be tracked by the parent effect:

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

Unless `failSilently` is set to `true`, this function will emit a warning if there is no active effect or scope.

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

| Flag              | Default  | Description                                                                                                                                            |
| ----------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| strict            | `true`\* | Enforces synchronous, non-yielding behavior in signals, effects, and other critical code.                                                              |
| frozen            | `true`\* | Enforces data immutability by deep-freezing tables passed to signals, excluding objects with metatables.                                               |
| trackInnerEffects | `true`   | Whether nested effects should be tracked and cleaned up when the parent effect re-runs. This should only be disabled to debug issues during migration. |

The `strict` and `frozen` flags are automatically enabled in Roblox Studio and other development environments where the Luau optimization level is `O1` or lower.

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
local ageAtom = atom(20)

return {
	getName = getName,
	setName = setName,
	getSurname = getSurname,
	setSurname = setSurname,
	ageAtom = ageAtom,
}
```

When a player joins on the server, call `server.addSignalsToClient` with the keyed signals that the client should receive updates for. Once they leave, call `server.removeClient` to unsubscribe them from all updates.

Then, use `server.connect` to specify how state updates should be sent to each client. Pass a callback function that fires a remote with the given target player and the state updates they subscribed to.

```luau
local function onPlayerAdded(player: Player)
	-- Add signal getters, computed signals, atoms, or reactive objects
	server.addSignalsToClient(player, {
		name = nameStore.getName,
		surname = nameStore.getSurname,
		age = nameStore.ageAtom,
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
-- Add signal setters, atoms, or reactive proxies
client.addSignals({
	name = nameStore.setName,
	surname = nameStore.setSurname,
	age = nameStore.ageAtom,
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

You can pass signal getter functions, computed signals, atoms, and [reactive objects](#reactiveinitialvalue) in the `getters` table. This function can also be called multiple times on the same client to subscribe to new signals.

```luau
Players.PlayerAdded:Connect(function(player)
	server.addSignalsToClient(player, {
		name = nameStore.getName,
		surname = nameStore.getSurname,
		age = nameStore.ageAtom,
	})
end)
```

You're also allowed to create new signals to sync to specific players, as long as the key is unique to that player:

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
	name = nameStore.getName,
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

You can pass either writable signals, atoms, or [reactive objects](#reactiveinitialvalue) to this function:

```luau
client.addSignals({
	name = nameStore.setName,
	surname = nameStore.setSurname,
	age = nameStore.ageAtom,
})
```

---

### `client.removeSignals(...keys)`

Unsubscribes from each signal with the corresponding keys. The signals will retain their current values, but will no longer receive updates from the server.

```luau
client.addSignals({
	name = nameStore.setName,
	surname = nameStore.setSurname,
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

### `signalToAtom(getter, setter)`

If you have a lot of signals to sync between the server and clients, it might become difficult to keep track of many getters and setters. The `signalToAtom()` function unifies a signal's `get()` and `set()` functions, allowing you to reuse the same values for `client.addSignals` and `server.addSignalsToClient`.

```luau
local sharedState = {
	name = signalToAtom(nameStore.getName, nameStore.setName),
	surname = signalToAtom(nameStore.getSurname, nameStore.setSurname),
}

client.addSignals(sharedState)
server.addSignalsToClient(client, sharedState)
```

---

### Sync Caveats

Charm Sync will only send clients the differences between the current state and the last-synced state through a process called _delta compression_. In this case, tables are recursively scanned for changes, and unchanged properties are omitted by setting them to `nil`.

But it's hard to differentiate between an unchanged value and a removed value, as both cases are represented by `nil`. We chose to address this by representing deleted values with a special `None` symbol denoted by `{ __none = "__none" }`.

This means nilable values may be replaced with `None` in patches, and code working with update payloads (usually for remote argument serialization) should account for nilable values possibly being sent as `None` in the payload.

---

## Deep Reactivity

Charm's reactivity system is _shallow_ by default: only the top-level value is reactive, so table properties are not checked when determining whether a signal has updated. As a result, tables in Charm should be immutable (copied before writing) in order to signal that a table's properties have changed.

Deep reactivity, on the other hand, uses proxy tables to perform dependency tracking on properties. You can subscribe to a property by indexing the proxy table, and setting a property will notify its subscribers. This approach to reactivity lets you work with mutable data, making state management more intuitive at the cost of added overhead.

You can opt-in to deep reactivity with the Deep Charm library:

### Installation

```sh
npm install @rbxts/deep-charm
yarn add @rbxts/deep-charm
pnpm add @rbxts/deep-charm
```

```toml
[dependencies]
DeepCharm = "littensy/deep-charm@VERSION"
```

---

### `reactive(initialValue)`

The `reactive()` function takes a mutable table and wraps it in a reactive proxy. Reading properties through the proxy will perform dependency tracking, and nested tables will also be wrapped in a reactive proxy.

```luau
local users, updateUsers = reactive({
	{ name = "John", surname = "Doe" },
})

effect(function()
	print(`{users[1].name} {users[1].surname}`)
end) -- Output: John Doe

updateUsers(function(raw)
	raw[1].name = "Jane"
	raw[1].surname = "Smith"
	table.insert(raw, { name = "Steve", surname = "Doe" })
end) -- Output: Jane Smith

-- You can also mutate the reactive proxy directly:
users[1].name = "John" -- John Smith
```

### Mutation vs. update function

Because reactive proxies use metatables for reading and writing, functions like `table.insert` will not work on the proxy. Table functions should only be called on the raw table value, which you can access through the update function returned by `reactive()`.

This update function (`updateUsers()` in the example above) passes the raw table for you to mutate. Once your callback is done executing, the updater will manually notify subscriptions to the reactive proxy and its nested properties. This process does not use metatables, so you should use this for table operations or batching updates.

---

### `toRaw(value)`

If you need to access the raw table through the reactive proxy, use the `toRaw()` function:

```luau
local raw = {}
local proxy = reactive(raw)

print(toRaw(proxy) == raw) -- true
```

---

### `isReactive(value)`

The `isReactive()` function returns `true` if the given value is a reactive proxy by checking its metatable.

```lua
local raw = {}
local proxy = reactive(raw)

print(isReactive(proxy)) -- true
print(isReactive(raw)) -- false
```

---

## Migration

Charm v0.11 introduces several breaking changes, so this section should help you migrate from an older version.

For reference, a signal is a state container with a separated getter and setter function. Atoms are a signal with a single function for getting and setting the state.

**What to look out for:**

1. Address all of the type errors introduced in your project after updating Charm. Most of them are caused by changes like:
    - `peek()` was changed to `untracked()` for parity with other state managers
    - The second arguments of `atom()` changed from an `options` table to an equality function
    - Removed the second argument of `computed()` (you can do your own equality checks since the computed callback now receives the previous value)
    - Removed the cleanup argument in effect callbacks (`effect(function(cleanup) end)`)

2. If you use Charm Sync, you'll have to rewrite a lot of your sync code. Fortunately, most of the changes should make your code _less_ complicated:
    - You can now sync signals per-client, including computed signals. You shouldn't have to modify sync payloads to filter data anymore.
    - Instead of creating client/server syncers, these modules now act like singletons. Sync APIs are called directly through `CharmSync.client`/`server`.
    - [Read the updated docs for syncing state →](#client-server-sync)

3. The [`strict` and `frozen` flags](#flags) are automatically enabled in Roblox Studio, so unsafe Charm code will start throwing errors. The flags have the following behaviors:
    - `strict`: Yielding in effects, signals, and other critical Charm functions will throw an error
    - `frozen`: Tables passed to signals are deeply frozen to strictly enforce data immutability and prevent accidental mutations

4. Nested effects automatically clean up when the parent effect re-runs or gets disposed. In other words, all effects created during the execution of another effect will be added as a "child" and clean up with the parent effect. This might cause issues in code that relied on the old behavior, where effects were detached from the parent.
    - This feature applies to the observer function in `observe()`, which also automatically cleans up inner effects to prevent memory leaks. However, this does not apply to `subscribe()` or `listen()`.
    - Effects that should not be tracked by a parent effect/scope should be wrapped in [`untracked()`](#untrackedcallback).
    - This feature can introduce runtime bugs in migrated code. If you suspect this to be the cause, to help identify the issue, you can temporarily disable this feature by setting [`flags.trackInnerEffects`](#flags) to `false`.

5. Consider refactoring your code to use some new quality-of-life features. Many of these are made possible thanks to [alien-signals](https://github.com/stackblitz/alien-signals)!
    - [`signal()`](#signalinitialvalue-equals): make atom reads and writes more explicit
    - [`listen()`](#listengetter-callback): create a subscription that also runs once immediately
    - [`effectScope()`](#effectscopecallback): collect and clean up multiple effects at once
    - [`onCleanup()`](#oncleanupcallback-failsilently): bind a cleanup function to the active effect or scope
    - [`trigger()`](#triggercallback): trigger updates for table mutations

---

## Examples

- https://github.com/littensy/fishing-minigame: Fisch clone using Charm for server and client state

### React Counter

```luau
local Charm = require("@packages/charm")
local ReactCharm = require("@packages/react-charm")
local React = require("@packages/react")

local getCounter, setCounter = Charm.signal(0)

local function Counter()
	local count = ReactCharm.useSignalState(getCounter)

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
local Charm = require("@packages/charm")
local VideCharm = require("@packages/vide-charm")
local Vide = require("@packages/vide")

local create = Vide.create

local getCounter, setCounter = Charm.signal(0)

local function Counter()
	local count = VideCharm.useSignalState(getCounter)

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
Charm is released under the <a href="LICENSE">MIT License</a>.
</p>

<div align="center">

[![MIT License](https://img.shields.io/github/license/littensy/charm?style=for-the-badge)](LICENSE)

</div>
