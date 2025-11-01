local alien = require("./alien")
local globals = require("./globals")
local utils = require("./utils")

export type ReactiveFlags = alien.ReactiveFlags
export type ReactiveNode = alien.ReactiveNode
export type Link = alien.Link

local ReactiveFlags = alien.ReactiveFlags
local createReactiveSystem = alien.createReactiveSystem
local deepFreeze = utils.deepFreeze
local noYield = utils.noYield

--[[
	Reactive system adapted from alien-signals at
	https://github.com/stackblitz/alien-signals/blob/master/src/index.ts

	MIT License

	Copyright (c) 2024-present Johnson Chu

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

local NONE = 0b0000000
local MUTABLE = 0b0000001
local WATCHING = 0b0000010
local RECURSED_CHECK = 0b0000100
local DIRTY = 0b0010000
local PENDING = 0b0100000
local PEEKING = 0b1000000

type EffectScope = ReactiveNode & {
	cleanups: { () -> () },
}

type Effect = ReactiveNode & {
	fn: (stop: () -> ()) -> (() -> ())?,
	cleanups: { () -> () },
	stop: () -> (),
}

type Computed<T = any> = ReactiveNode & {
	value: T?,
	getter: (previousValue: T?) -> T,
}

type Signal<T = any> = ReactiveNode & {
	currentValue: T,
	pendingValue: T,
}

local link: (dep: ReactiveNode, sub: ReactiveNode, version: number) -> ()
local unlink: (link: Link, sub: ReactiveNode?) -> Link?
local propagate: (link: Link) -> ()
local checkDirty: (link: Link, sub: ReactiveNode) -> boolean
local shallowPropagate: (link: Link) -> ()

local cycle = 0
local batchDepth = 0
local notifyIndex = 0
local queued: { Effect? } = {}
local queuedLength = 0
local activeSub: ReactiveNode?

local function getActiveSub(): ReactiveNode?
	return activeSub
end

local function setActiveSub(sub: ReactiveNode?)
	local prevSub = activeSub
	activeSub = sub
	return prevSub
end

local function purgeDeps(sub: ReactiveNode)
	local depsTail = sub.depsTail
	local dep = if depsTail then depsTail.nextDep else sub.deps
	while dep do
		dep = unlink(dep, sub)
	end
end

local function runCleanups(effect: EffectScope)
	for _, cleanup in effect.cleanups do
		local prevSub = setActiveSub(nil)
		local success, result: any = (if globals.strict then noYield else pcall)(cleanup)
		activeSub = prevSub
		if not success then
			error(result)
		end
	end
	table.clear(effect.cleanups)
end

local function run(e: Effect): ()
	local flags = e.flags
	if bit32.btest(flags, DIRTY) or (bit32.btest(flags, PENDING) and checkDirty(e.deps :: Link, e)) then
		runCleanups(e)
		cycle += 1
		e.depsTail = nil
		e.flags = bit32.bor(WATCHING, RECURSED_CHECK)
		local prevSub = setActiveSub(e)
		local success, result: (() -> ())? = (if globals.strict then noYield else pcall)(e.fn, e.stop)
		activeSub = prevSub
		e.flags = bit32.band(e.flags, bit32.bnot(RECURSED_CHECK))
		purgeDeps(e)
		if not success then
			error(result)
		elseif result then
			table.insert(e.cleanups, result)
		end
	else
		e.flags = WATCHING
	end
end

local function flush(): ()
	while notifyIndex < queuedLength do
		local effect = queued[notifyIndex] :: Effect
		queued[notifyIndex] = nil
		notifyIndex += 1
		run(effect)
	end
	notifyIndex = 0
	queuedLength = 0
end

local function getBatchDepth(): number
	return batchDepth
end

local function startBatch()
	batchDepth += 1
end

local function endBatch()
	batchDepth -= 1
	if batchDepth == 0 then
		flush()
	end
end

local function updateComputed(c: Computed): boolean
	cycle += 1
	c.depsTail = nil
	c.flags = bit32.bor(MUTABLE, RECURSED_CHECK)
	local prevSub = setActiveSub(c)
	local oldValue = c.value
	local success, result: unknown = (if globals.strict then noYield else pcall)(c.getter, oldValue)
	activeSub = prevSub
	c.flags = bit32.band(c.flags, bit32.bnot(RECURSED_CHECK))
	purgeDeps(c)
	if not success then
		error(result)
	end
	if oldValue ~= result then
		if globals.frozen then
			deepFreeze(result)
		end
		c.value = result
		return true
	else
		return false
	end
end

local function updateSignal(s: Signal): boolean
	s.flags = MUTABLE
	local pendingValue = s.pendingValue
	if s.currentValue ~= pendingValue then
		s.currentValue = pendingValue
		return true
	else
		return false
	end
end

local function setNotPending(sub: ReactiveNode, flags: ReactiveFlags)
	sub.flags = bit32.band(flags, bit32.bnot(PENDING))
end

local function computedOper<T>(this: Computed<T>): () -> T
	return function(): T
		local flags = this.flags
		if
			bit32.btest(flags, DIRTY)
			or (bit32.btest(flags, PENDING) and (checkDirty(this.deps :: Link, this) or setNotPending(this, flags)))
		then
			if updateComputed(this) then
				local subs = this.subs
				if subs then
					shallowPropagate(subs)
				end
			end
		elseif flags == NONE then
			this.flags = MUTABLE
			local prevSub = setActiveSub(this)
			local success, result = pcall(this.getter)
			activeSub = prevSub
			if success then
				this.value = result
			else
				error(result)
			end
		end
		if activeSub then
			link(this, activeSub, cycle)
		end
		return this.value :: T
	end
end

local function signalOper<T>(
	this: Signal<T>,
	equals: ((current: T, incoming: T) -> boolean)?
): (() -> T, (((T) -> T) | T) -> T)
	local function setter(update: ((T) -> T) | T): T
		local value: T
		if type(update) == "function" then
			local prevSub = setActiveSub(nil)
			local success, result: T = (if globals.strict then noYield else pcall)(update, this.currentValue)
			activeSub = prevSub
			if not success then
				error(result)
			end
			value = result
		else
			value = update
		end
		if if equals then not equals(this.pendingValue, value) else this.pendingValue ~= value then
			if globals.frozen then
				deepFreeze(value)
			end
			this.pendingValue = value
			this.flags = bit32.bor(MUTABLE, DIRTY)
			local subs = this.subs
			if subs then
				propagate(subs)
				if batchDepth == 0 then
					flush()
				end
			end
			return value
		end
		return this.currentValue
	end

	local function getter(): T
		if bit32.btest(this.flags, DIRTY) then
			if updateSignal(this) then
				local subs = this.subs
				if subs then
					shallowPropagate(subs)
				end
			end
		end
		local sub = activeSub
		while sub do
			if bit32.btest(sub.flags, bit32.bor(MUTABLE, WATCHING)) then
				link(this, sub, cycle)
				break
			end
			local subs = sub.subs
			if subs then
				sub = subs.sub
			end
		end
		return this.currentValue
	end

	return getter, setter
end

local function effectScopeOper(this: EffectScope): () -> ()
	return function()
		this.depsTail = nil
		this.flags = NONE
		purgeDeps(this)
		local sub = this.subs
		if sub then
			unlink(sub, this)
		end
		runCleanups(this)
	end
end

local function effectOper(this: Effect): () -> ()
	return effectScopeOper(this)
end

--- Creates a reactive signal that stores a value and notifies subscribers when
--- the value changes. The signal provides both a getter and a setter.
---
--- @param initialValue The initial value of the signal.
--- @param equals A comparator function to determine if the signal's value has changed.
--- @return A tuple containing the getter and setter functions for the signal.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#signalstate-equals
local function signal<T>(
	initialValue: T,
	equals: ((current: T, incoming: T) -> boolean)?
): (() -> T, (((T) -> T) | T) -> T)
	if globals.frozen then
		deepFreeze(initialValue)
	end
	return signalOper({
		currentValue = initialValue,
		pendingValue = initialValue,
		flags = MUTABLE,
	}, equals)
end

--- Creates a reactive atom that acts as both a getter and setter. Calling the
--- atom with an argument sets its value, while calling it with no arguments
--- returns its current value.
---
--- @param value The initial value of the atom. If empty, the atom's value will be `undefined`.
--- @param equals A comparator function to determine if the atom's value has changed.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#atomstate-equals
local function atom<T>(initialValue: T, equals: ((current: T, incoming: T) -> boolean)?): (...((T) -> T) | T) -> T
	local getter, setter = signal(initialValue, equals)
	return function(...)
		return if select("#", ...) == 0 then getter() else setter((...))
	end
end

--- Creates a new atom that is computed based on the values of other atoms.
--- The returned atom is read-only, and its value is automatically updated when
--- any atoms accessed from within the getter function change.
---
--- @example
--- ```ts
--- const count = atom(1);
--- const plusOne = computed(() => count() + 1);
--- print(plusOne()); // 2
--- ```
---
--- @param getter A function that produces the next value.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#computedgetter
local function computed<T>(getter: (previousValue: T?) -> T): () -> T
	return computedOper({
		flags = NONE,
		getter = getter,
	})
end

--- Creates an effect that runs a callback in response to atom state changes.
--- An effect tracks which atoms are accessed during its execution, and re-runs
--- the callback when those atoms change.
---
--- The effect callback may return a cleanup function, which gets called once,
--- either before the effect re-runs or when it is disposed.
---
--- If the effect is called within another effect, it will be disposed when the
--- outer effect re-runs.
---
--- @param fn The function to run when dependencies change.
--- @return A function for disposing the effect.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#effectcallback
local function effect(fn: (stop: () -> ()) -> ()): () -> ()
	local e: Effect = {
		fn = fn,
		flags = WATCHING,
		cleanups = {},
		stop = nil :: any,
	}
	e.stop = effectOper(e)
	local prevSub = setActiveSub(e)
	if prevSub and (globals.trackInnerEffects or prevSub.flags == NONE) then
		link(e, prevSub, 0)
	end
	local stopped = false
	local success, result: (() -> ())? = (if globals.strict then noYield else pcall)(fn, function()
		stopped = true
	end)
	activeSub = prevSub
	if not success then
		error(result)
	elseif result then
		table.insert(e.cleanups, result)
	end
	if stopped then
		e.stop()
	end
	return e.stop
end

--- Creates an effect scope that can capture multiple reactive effects (i.e.
--- computed, effect, subscribe) created within it so that they can be disposed
--- together.
---
--- @param fn A function that may create reactive effects.
--- @param detached If true, the scope will not be automatically disposed of when the parent scope is disposed. Defaults to false.
--- @return A function for disposing all effects created within the scope.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#effectscopecallback-detached
local function effectScope(fn: () -> (), detached: boolean?): () -> ()
	local e: EffectScope = {
		flags = NONE,
		cleanups = {},
	}
	local prevSub = setActiveSub(e)
	if prevSub and not detached then
		link(e, prevSub, 0)
	end
	local success, result: (() -> ())? = (if globals.strict then noYield else pcall)(fn)
	activeSub = prevSub
	if not success then
		error(result)
	elseif result then
		table.insert(e.cleanups, result)
	end
	return effectScopeOper(e)
end

--- Registers a cleanup function to the current active effect or effect scope.
--- If there is no active effect or scope, a warning is logged and the callback
--- is not registered, unless `failSilently` is set to true.
---
--- @param callback The cleanup function to register.
--- @param failSilently If true, suppresses the warning when there is no active effect or scope. Defaults to false.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#oncleanupcallback-failsilently
local function onCleanup(cleanup: () -> (), failSilently: boolean?)
	if activeSub and (activeSub :: Effect).cleanups then
		table.insert((activeSub :: Effect).cleanups, cleanup)
	elseif not failSilently then
		warn(debug.traceback("onCleanup() can only be called inside an effect or a scope.", 2))
	end
end

--- Runs the callback without subscribing to atom updates or capturing inner
--- effects in the parent effect or scope.
---
--- For an alternative that still cleans up inner effects, use `peek` instead.
---
--- @param callback The callback function.
--- @param args Arguments to pass to the callback.
--- @return The return value of the callback.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#untrackedcallback
local function untracked<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	local prevSub = setActiveSub(nil)
	local results: { any } = { pcall(callback, ...) }
	activeSub = prevSub
	if not results[1] then
		error(results[2])
	end
	return unpack(results, 2)
end

--- Runs the callback without subscribing to atom updates, but still captures
--- inner effects so that they dispose with the parent effect.
---
--- To avoid capturing inner effects, use `untracked` instead.
---
--- @param callback The callback function.
--- @param args Arguments to pass to the callback.
--- @return The return value of the callback.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#peekcallback
local function peek<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	if
		activeSub
		and bit32.band(activeSub.flags, PEEKING) == 0
		and bit32.btest(activeSub.flags, bit32.bor(WATCHING, MUTABLE))
	then
		activeSub.flags = bit32.bor(activeSub.flags, PEEKING)
		local results: { any } = { pcall(callback, ...) }
		activeSub.flags = bit32.band(activeSub.flags, bit32.bnot(PEEKING))
		if not results[1] then
			error(results[2])
		end
		return unpack(results, 2)
	else
		return callback(...)
	end
end

--- Combines multiple atom updates into a single "commit" that runs effects at
--- the end of the provided callback.
---
--- @param callback A function that performs multiple atom updates.
--- @param args Arguments to pass to the callback.
--- @return The return value of the callback.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#batchedcallback
local function batched<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	startBatch()
	local results: { any } = { (if globals.strict then noYield else pcall)(callback, ...) }
	endBatch()
	if not results[1] then
		error(results[2])
	end
	return unpack(results, 2)
end

--- Creates an effect that only runs the callback when the value returned by the
--- getter changes. The callback receives the new value and the previous value
--- as arguments.
---
--- @param getter A function that returns the value to watch.
--- @param callback The function to run when the value changes.
--- @return A function for disposing the effect.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#subscribegetter-callback
local function subscribe<T>(getter: () -> T, callback: (state: T, lastState: T) -> ()): () -> ()
	local tracked = computed(function()
		return getter()
	end)
	local current: T
	local mounted = true
	return effect(function()
		local previous = current
		current = tracked()
		if mounted then
			mounted = false
		else
			peek(callback, current, previous)
		end
	end)
end

--- Creates an effect that runs the callback one immediately, and then again
--- when the value returned by the getter changes. The callback receives the new
--- value, the previous value, and a cleanup function as arguments.
---
--- @param getter A function that returns the value to watch.
--- @param callback The function to run when the value changes.
--- @return A function for disposing the effect.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#listengetter-callback
local function listen<T>(getter: () -> T, callback: (state: T, previous: T?, dispose: () -> ()) -> ()): () -> ()
	local tracked = computed(function()
		return getter()
	end)
	local current: T
	local disposed = false
	local dispose = function()
		disposed = true
	end
	dispose = effect(function()
		local previous = current
		current = tracked()
		peek(callback, current, previous, dispose)
	end)
	if disposed then
		dispose()
	end
	return dispose
end

local reactiveSystem = createReactiveSystem({
	update = function(node)
		if node.depsTail then
			return updateComputed(node :: Computed)
		else
			return updateSignal(node :: Signal)
		end
	end,
	notify = function(effect)
		local insertIndex = queuedLength
		local firstInsertedIndex = insertIndex

		repeat
			effect.flags = bit32.band(effect.flags, bit32.bnot(WATCHING))
			queued[insertIndex] = effect :: Effect
			insertIndex += 1
			effect = (effect.subs and effect.subs.sub) :: Effect
			if not effect or bit32.band(effect.flags, WATCHING) == 0 then
				break
			end
		until false

		queuedLength = insertIndex

		insertIndex -= 1
		while firstInsertedIndex < insertIndex do
			local left = queued[firstInsertedIndex]
			queued[firstInsertedIndex] = queued[insertIndex]
			queued[insertIndex] = left
			firstInsertedIndex += 1
			insertIndex -= 1
		end
	end,
	unwatched = function(node)
		if bit32.band(node.flags, MUTABLE) == 0 then
			effectScopeOper(node :: EffectScope)()
		elseif node.depsTail then
			node.depsTail = nil
			node.flags = bit32.bor(MUTABLE, DIRTY)
			purgeDeps(node)
		end
	end,
})

link = reactiveSystem.link
unlink = reactiveSystem.unlink
propagate = reactiveSystem.propagate
checkDirty = reactiveSystem.checkDirty
shallowPropagate = reactiveSystem.shallowPropagate

return {
	ReactiveFlags = ReactiveFlags,
	createReactiveSystem = createReactiveSystem,
	getActiveSub = getActiveSub,
	setActiveSub = setActiveSub,
	getBatchDepth = getBatchDepth,
	startBatch = startBatch,
	endBatch = endBatch,
	atom = atom,
	signal = signal,
	computed = computed,
	effect = effect,
	effectScope = effectScope,
	onCleanup = onCleanup,
	untracked = untracked,
	peek = peek,
	batched = batched,
	subscribe = subscribe,
	listen = listen,
}
