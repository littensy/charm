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

**Charm** is a state management library that aims to bring [reactive signals](https://preactjs.com/blog/signal-boosting/) from libraries like Preact and Solid to Roblox. It's built on the [alien-signals](https://github.com/stackblitz/alien-signals) signal algorithm, expanding upon it further to handle a wide range of use cases, from rendering user interfaces to handling server game logic.

**Charm has a few core principles:**

- Manage state with reactive signals: state containers that hold a value
- React to state updates: reading a signal automatically subscribes to it
- Combine multiple signals: derive a new value from existing state that stays up-to-date
- Fine-grained reactivity: make targeted updates in response to specific changes in the state
- Use immutable data: values are compared directly (`==`) to optimize change detection

**Want to learn more about signals?**

- https://preactjs.com/blog/signal-boosting
- https://docs.solidjs.com/advanced-concepts/fine-grained-reactivity
- https://angular.dev/guide/signals

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

</summary>
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

## Guide

### `signal(initialValue, equals?)`

Signals are the core of reactivity in Charm. The `signal` function creates a reactive signal that acts as a container for a value. It returns a function to access the value, and another to update the value.

```luau
local getCounter, setCounter = signal(0)

print(getCounter()) --> 0
setCounter(1)
setCounter(function(count)
	return count + 1
end)
```

Accessing the signal's value in an effect or computed signal will subscribe to it as a dependency. Changing the value will immediately update every effect and computed signal that depends signal, ensuring every part of your state is correct and up-to-date.

You can also pass a custom equality function to only update the signal if the new value is _not_ equal to the current value:

```luau
local getMax, setMax = signal(0, function(incoming, current)
	return incoming <= current
end)

setMax(1) --> 1
setMax(-1) --> 1
```

> [!NOTE]
> Looking for atoms? You can still use `atom()` to create a signal with a combined getter and setter. To use signals for APIs that require atoms, use `signalToAtom()`.

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

print(getFullName()) --> "John Doe"
setName("Jane")
print(getFullName()) --> "Jane Doe"
```

The getter function also receives the previous state (or `nil` if running for the first time). You can use this for more complex state:

```luau
local getCounter, setCounter = signal(10)
local getMax = computed(function(prevMax)
	return math.max(getCounter(), prevMax or 0)
end)

print(getMax()) --> 10
setCounter(5)
print(getMax()) --> 10
```

Computed signals are updated lazily, meaning the getter will only re-execute once the computed signal is called _and_ if a dependency updated since the last call.

---

### `effect(callback)`

Effects are fundamental to reactivity, allowing you to react to signal updates. The `effect` function subscribes to signals accessed by the effect callback, and when a dependency updates, the callback will re-execute.

```luau
local getCounter, setCounter = signal(0)

effect(function()
	print(`Count is {getCounter()}`)
end) --> Count is 0

setCounter(1) --> Count is 1
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

setCounter(1) --> Cleanup 0
dispose() --> Cleanup 1
```

Effects can be nested and they will clean up automatically when the parent effect re-runs or gets disposed. This means you don't have to manually clean up inner effects, and this applies to functions like `subscribe()` and `observe()`.

> [!NOTE]
> To run code that is "detached" from the parent effect or scope, use `untracked()` or a detached effect scope. If you suspect that the new nested effect behavior is causing issues with migration, try disabling the `globals.trackInnerEffects` flag to assist with debugging.

```luau
local getCounter, setCounter = signal(0)

effect(function()
	print(`Outer: {getCounter()}`)
	effect(function()
		print(`Inner: {getcounter()}`)
	end)
end)

setCounter(1) --> Outer: 1, Inner: 1
setCounter(2) --> Outer: 2, Inner: 2
```

---

### `untracked(callback)`

In case you want to read signals that you don't want to subscribe to, you can use `untracked()` to essentially call a function _outside_ the current effect, preventing signals and effects in the callback from being tracked.

```luau
local getCounter, setCounter = signal(0)
local getRuns, setRuns = signal(0)

effect(function()
	local runs = untracked(getRuns) + 1
	setRuns(runs)
	print(`Count is {getCounter()}, ran {runs} times`)
end) --> Count is 0, ran 1 times

setCounter(10) --> Count is 10, ran 2 times
setRuns(10) -- No output
setCounter(20) --> Count is 20, ran 11 times
```

Because `untracked()` executes the callback outside the current effect, nested effects created in the callback do not get tracked by the parent effect:

```luau
local disposeInner
local disposeOuter = effect(function()
	untracked(function()
		disposeInner = effect(function()
			return function()
				print("Cleaned up inner effect")
			end
		end)
	end)
end)

disposeOuter() -- No output; outer effect did not track inner effect
disposeInner() --> Cleaned up inner effect
```

---

### `peek(callback)`

Similar to `untracked()`, but does not prevent effects created by the callback from automatically disposing. If your callback reads a signal and creates effects, only the signals get untracked.

```luau
local getCounter, setCounter = signal(0)
local disposeOuter = effect(function()
	peek(function()
		print(`Count is {getCounter()}`)
		effect(function()
			return function()
				print("Cleaned up inner effect")
			end
		end)
	end)
end) --> Count is 0

setCounter(1) -- No output; count was accessed in peek()
disposeOuter() --> Cleaned up inner effect
```

---

### `batched(callback)`

Combines multiple signal updates made by the callback into a single commit that gets triggered when the callback completes.

```luau
local getName, setName = signal("John")
local getSurname, setSurname = signal("Doe")

effect(function()
	print(`Full name: {getName()} {getSurname()}`)
end)

-- Combines both writes into a single update.
-- Once the callback completes, outputs "Full name: Foo Bar"
batched(function()
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

setCounter(1) --> Count 1 is 1, Count 2 is 1
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
end) --> Count is 0 (was nil)

setCounter(1) --> Count is 1 (was 0)
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

setCounter(1) --> Count is 1 (was 0)
```

Note that nested effects can be created inside `subscribe`, and they will clean up automatically when the subscription re-runs or gets disposed.

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
end) --> Added a, Added b

setItems({ a = 0, c = 0 }) --> Removed b, Added c
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

setItems({ a = 1, b = 0 }) --> Cleanup a = 0, a = 1
setItems({ a = 1 }) --> Cleanup b = 0
dispose() --> Cleanup a = 1
```

---

### `mapped(getter, mapper)`

The `mapped` function iterates over every key in a table and uses the mapper to generate a new key and value. The resulting table is returned in a read-only signal containing the new keys and values. When a key's value changes, or a new key is added to the table, the mapper is called for that key and its current value.

The first value returned by the mapper is used as the new value:

```luau
local getList, setList = signal({ "a", "b", "c" })

local getUppercase = mapped(getList, function(value)
	return string.upper(value)
end)

print(getUppercase()) --> { "A", "B", "C" }
```

If the mapper returns two values, the second value is used as the new key:

```luau
local getList, setList = signal({ "a", "b", "c" })

local getSwapped = mapped(getList, function(value, key)
	return key, value
end)

print(getSwapped()) --> { a = 1, b = 2, c = 3 }
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

dispose() --> Cleaned up
```

---

### `atom(initialValue, equals?)`

The `atom` function creates a new reactive signal and returns a single function that acts as both a getter and setter.

If the atom is called with 0 arguments, the atom returns the current value and subscribes to the signal. Otherwise, when called with 1 or more arguments, the atom will update the signal's value.

```luau
local counter = atom(0)

print(counter()) --> 0
counter(1)
counter(function(count)
	return count + 1
end)
```

You can also pass a custom equality function to only update the signal if the new value is _not_ equal to the current value:

```luau
local max = atom(0, function(incoming, current)
	return incoming <= current
end)

max(1) --> 1
max(-1) --> 1
```

---

## Examples

Check out this simple [example project →](https://github.com/littensy/charm-example)

### React Counter

```luau
local counterStore = require("./stores/counterStore")

local function Counter()
	local count = useSignalState(counterStore.getCounter)

	return React.createElement("TextButton", {
		[React.Event.Activated] = counterStore.incrementCounter,
		Text = `Count: {count}`,
		Size = UDim2.fromOffset(100, 50),
	})
end
```

### Vide Counter

```luau
local counterStore = require("./stores/counterStore")

local function Counter()
	local count = useSignalState(counterStore.getCounter)

	return create "TextButton" {
		Activated = counterStore.incrementCounter,
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
