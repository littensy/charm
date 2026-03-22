--[[
	Reactive system adapted from alien-signals at
	https://github.com/stackblitz/alien-signals/blob/master/src/system.ts
]]

local system = require("@self/system")

export type Link = system.Link
export type ReactiveFlags = system.ReactiveFlags
export type ReactiveNode = system.ReactiveNode

local link = system.link
local unlink = system.unlink
local propagate = system.propagate
local checkDirty = system.checkDirty
local shallowPropagate = system.shallowPropagate
local createReactiveSystem = system.createReactiveSystem

export type Getter<T> = () -> T
export type Setter<T> = (update: Update<T>) -> T
export type Atom<T = any> = (...Update<T>) -> T
export type Update<T> = ((current: T) -> T) | T
export type Equals<T> = (current: T, incoming: T) -> boolean
export type Cleanup = () -> ()

type EffectScopeNode = ReactiveNode & {
	cleanups: { Cleanup },
}

type EffectNode = ReactiveNode & {
	fn: () -> ...Cleanup?,
	cleanups: { Cleanup },
}

type ComputedNode<T = any> = ReactiveNode & {
	value: T?,
	getter: (previousValue: T?) -> T,
}

type SignalNode<T = any> = ReactiveNode & {
	currentValue: T,
	pendingValue: T,
}

-- Bitmask flags for tracking the state of reactive nodes. Flags are combined
-- and checked using bitwise operations for efficiency.
local NONE = 0b000000 -- Default state
local MUTABLE = 0b000001 -- Can be changed (signal or computed)
local WATCHING = 0b000010 -- Watching for changes (effects)
local RECURSED_CHECK = 0b000100 -- Being checked for circular dependencies
local DIRTY = 0b010000 -- Value has changed and needs updating
local PENDING = 0b100000 -- Might be dirty, pending verification

-- Global version counter for dependency link deduplication. Incremented at the
-- start of each effect/computed run to ensure links created in the same cycle
-- are deduplicated.
local cycle = 0
-- Effects runs are queued to prevent redundant executions when multiple
-- signals update in the same batch.
local queued: { EffectNode? } = {}
local queuedLength = 0
local notifyIndex = 0
-- Batch operations group multiple updates together, deferring effect runs
-- until the batch completes. Effects only run when the outermost batch ends.
local batchDepth = 0
-- Tracks the currently active effect or computed signal during execution.
-- Dependencies accessed during this time will link to the active subscriber.
local activeSub: ReactiveNode?

local function isO2(): boolean
	return debug.info(1, "n") ~= "isO2"
end

local flags = {
	--[[
		Enforces synchronous, non-yielding behavior in signals and effects.
		Also enables state validation in Charm Sync to catch sync errors early.
		Enabled if the optimization level is below 2, which is true in studio.
	]]
	strict = not isO2(),
	--[[
		Enforces immutability of tables by deep-freezing table values. Enabled
		if the optimization level is below 2, which is true in studio.
	]]
	frozen = not isO2(),
	--[[
		Whether parent effects should track inner effects and clean them up
		when the parent effect re-runs. This is usually desirable, but can be
		disabled to revert to the old behavior. Defaults to `true`.
	]]
	trackInnerEffects = true,
}

--[[
	Wraps a function to prevent yielding when in strict mode. If the function
	attempts to yield, an error is thrown.

	@param fn The function to wrap.
	@return A wrapped function that cannot yield in strict mode.
]]
local function noYield<Args..., Results...>(fn: (Args...) -> Results...): (Args...) -> Results...
	if not flags.strict then
		return fn
	end

	local function resultHandler(thread: thread, ok: boolean, ...)
		if not ok then
			error(debug.traceback(thread, tostring((...))))
		elseif coroutine.status(thread) ~= "dead" then
			error(debug.traceback(thread, "Yielding is not allowed in strict mode"))
		end
		return ...
	end

	return function(...)
		local thread = coroutine.create(fn)
		return resultHandler(thread, coroutine.resume(thread, ...))
	end
end

--[[
	Recursively freezes a table and all nested tables to enforce immutability.
	Tables with metatables are skipped, as they are assumed to be mutable.

	@param value Table to freeze
]]
local function deepFreeze(value: any)
	if type(value) == "table" and not table.isfrozen(value) and getmetatable(value) == nil then
		table.freeze(value)
		for _, entry in value do
			deepFreeze(entry)
		end
	end
end

--[[
	Returns the currently active subscriber (effect or computed node).

	@return Current active subscriber or `nil`
]]
local function getActiveSub(): ReactiveNode?
	return activeSub
end

--[[
	Sets the currently active subscriber (effect or computed node) and returns
	the previous subscriber.

	@param sub New subscriber to set as active
	@return Previous active subscriber
]]
local function setActiveSub(sub: ReactiveNode?)
	local prevSub = activeSub
	activeSub = sub
	return prevSub
end

--[[
	Removes dependencies from the subscriber's dependency list. When called
	after tracking is complete, this ensures that only currently tracked
	dependencies remain linked.

	@param sub Effect or computed node
]]
local function purgeDeps(sub: ReactiveNode)
	local depsTail = sub.depsTail
	local dep = if depsTail then depsTail.nextDep else sub.deps
	while dep do
		dep = unlink(dep, sub)
	end
end

--[[
	Runs all cleanup functions registered with the effect node. Any errors
	thrown during cleanup are caught and logged as warnings.

	@param cleanups List of cleanup functions
]]
local function runCleanups(cleanups: { Cleanup })
	for key, cleanup in cleanups do
		local prevSub = setActiveSub(nil)
		cleanups[key] = nil
		xpcall(cleanup, function(err)
			warn("Error occurred during effect cleanup:", debug.traceback(tostring(err), 2))
		end)
		activeSub = prevSub
	end
end

--[[
	Checks if the effect node needs to run based on its flags and dependencies.
	Effects run if they are marked dirty or pending with dirty dependencies.

	@param effect Effect node to run
]]
local function run(effect: EffectNode)
	local flags = effect.flags

	if bit32.btest(flags, DIRTY) or (bit32.btest(flags, PENDING) and checkDirty(effect.deps :: Link, effect)) then
		runCleanups(effect.cleanups)

		cycle += 1
		effect.depsTail = nil
		effect.flags = WATCHING

		local prevSub = setActiveSub(effect)
		local success, result = pcall(effect.fn)
		activeSub = prevSub

		purgeDeps(effect)

		if not success then
			error(result)
		elseif result then
			table.insert(effect.cleanups, noYield(result))
		end
	else
		effect.flags = WATCHING
	end
end

--[[
	Processes the queued effect runs. Effects are run in the order they were
	queued, ensuring that all updates are processed.
]]
local function flush()
	while notifyIndex < queuedLength do
		local effect = queued[notifyIndex] :: EffectNode
		queued[notifyIndex] = nil
		notifyIndex += 1
		run(effect)
	end

	notifyIndex = 0
	queuedLength = 0
end

--[[
	Starts a batch operation, incrementing the batch depth counter. Effects
	will not run until the outermost batch ends.
]]
local function startBatch()
	batchDepth += 1
end

--[[
	Ends a batch operation, decrementing the batch depth counter. If this is
	the outermost batch, queued effects are flushed and run.
]]
local function endBatch()
	batchDepth -= 1
	if batchDepth == 0 then
		flush()
	end
end

--[[
	Updates a computed signal by re-evaluating its getter function. Returns
	whether the computed value changed.

	@param computed Computed node to update
	@return Boolean indicating whether the computed value changed
]]
local function updateComputed(computed: ComputedNode): boolean
	cycle += 1
	computed.depsTail = nil
	computed.flags = bit32.bor(MUTABLE, RECURSED_CHECK)

	local prevSub = setActiveSub(computed)
	local oldValue = computed.value
	local success, newValue = pcall(computed.getter, oldValue)
	activeSub = prevSub

	computed.flags = bit32.band(computed.flags, bit32.bnot(RECURSED_CHECK))
	purgeDeps(computed)

	if success then
		computed.value = newValue
		return oldValue ~= newValue
	else
		error(newValue)
	end
end

--[[
	Updates a signal by applying its pending value. Returns whether the
	signal's value changed.

	@param signal Signal node to update
	@return Boolean indicating whether the signal's value changed
]]
local function updateSignal(signal: SignalNode): boolean
	signal.flags = MUTABLE
	local pendingValue = signal.pendingValue
	if signal.currentValue ~= pendingValue then
		signal.currentValue = pendingValue
		return true
	else
		return false
	end
end

--[[
	Clears the pending flag from a subscriber. Used inside of if conditions to
	inline the operation.

	@param sub Effect or computed node
	@param flags Subscriber's current flags
]]
local function clearPending(sub: ReactiveNode, flags: ReactiveFlags)
	sub.flags = bit32.band(flags, bit32.bnot(PENDING))
end

--[[
	Performs a thorough cleanup of the given effect or effect scope:

	1. Removes all dependency links
	2. Unlinks from parent effects/scopes
	3. Clears state flags to mark the effect as inactive
	4. Runs all registered cleanup functions

	@param this Effect node
]]
local function stopEffect(this: EffectScopeNode)
	this.depsTail = nil
	this.flags = NONE

	purgeDeps(this)

	local sub = this.subs
	if sub then
		unlink(sub, this)
	end

	runCleanups(this.cleanups)
end

--[[
	Updates a signal or computed value and returns whether the value changed.

	@param node Signal or computed node
	@return Boolean indicating whether the value changed
]]
local function update(node: ReactiveNode): boolean
	if node.depsTail then
		return updateComputed(node :: ComputedNode)
	else
		return updateSignal(node :: SignalNode)
	end
end

--[[
	Queues an effect for execution, ensuring inner effects are notified in the
	correct order.

	@param effect Effect node to notify
]]
local function notify(effect: ReactiveNode)
	local insertIndex = queuedLength
	local firstInsertedIndex = insertIndex

	-- Collect inner effects in a chain
	repeat
		queued[insertIndex] = effect :: EffectNode
		insertIndex += 1

		effect.flags = bit32.band(effect.flags, bit32.bnot(WATCHING))
		effect = (effect.subs and effect.subs.sub) :: EffectNode

		if not effect or bit32.band(effect.flags, WATCHING) == 0 then
			break
		end
	until false

	queuedLength = insertIndex

	-- Reverse the collected effects to ensure outer effects run first
	while true do
		insertIndex -= 1
		if firstInsertedIndex >= insertIndex then
			break
		end
		queued[firstInsertedIndex], queued[insertIndex] = queued[insertIndex], queued[firstInsertedIndex]
		firstInsertedIndex += 1
	end
end

--[[
	Called when a node is not being watched by any subscribers. Cleans up the
	node's dependencies and performs the necessary cleanup operations:

	- Computed signals: Unlink dependencies and mark as dirty for potential future updates
	- Effects/scopes: Perform full cleanup to free resources

	@param node Reactive node (computed or effect/scope)
]]
local function unwatched(node: ReactiveNode)
	if bit32.band(node.flags, MUTABLE) == 0 then
		stopEffect(node :: EffectScopeNode)
	elseif node.depsTail then
		node.depsTail = nil
		node.flags = bit32.bor(MUTABLE, DIRTY)
		purgeDeps(node)
	end
end

--[[
	Creates a reactive signal that stores a value and notifies subscribers when
	the value changes. The signal provides both a getter and a setter.

	@param initialValue Initial value for the signal
	@param equals Optional comparator function to check for value changes
	@return Getter function to read the signal value
	@return Setter function to update the signal value
	@see https://github.com/littensy/charm?tab=readme-ov-file#signalinitialValue-equals
]]
local function signal<T>(initialValue: T, equals: Equals<T>?): (Getter<T>, Setter<T>)
	local this: SignalNode = {
		currentValue = initialValue,
		pendingValue = initialValue,
		flags = MUTABLE,
	}

	if flags.frozen then
		deepFreeze(initialValue)
	end

	local function writeSignal(update: Update<T>): T
		local value: T

		-- Determine the new value based on whether the update is a function or
		-- a direct value
		if type(update) == "function" then
			local prevSub = setActiveSub(nil)
			local success, result = pcall(noYield(update), this.pendingValue)
			activeSub = prevSub

			if success then
				value = result
			else
				error(result)
			end
		else
			value = update
		end

		-- Check if the new value is different from the pending value
		if if equals then not equals(this.pendingValue, value) else this.pendingValue ~= value then
			if flags.frozen then
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

	local function readSignal(): T
		-- Check if the signal needs to be updated (for signals within effects)
		if bit32.btest(this.flags, DIRTY) then
			if updateSignal(this) then
				local subs = this.subs
				if subs then
					shallowPropagate(subs)
				end
			end
		end

		-- Register this signal as a dependency of the active subscriber
		local sub = activeSub
		while sub do
			if bit32.btest(sub.flags, bit32.bor(MUTABLE, WATCHING)) then
				link(this, sub, cycle)
				break
			end
			local subs = sub.subs
			sub = if subs then subs.sub else nil
		end

		return this.currentValue
	end

	return readSignal, writeSignal
end

--[[
	Creates a signal and returns a function that can act as both the getter and
	setter. Calling the atom with one argument sets its value, while calling it
	with no arguments returns its current value.

	@param initialValue Initial value for the atom
	@param equals Optional comparator function to check for value changes
	@see https://github.com/littensy/charm?tab=readme-ov-file#atominitialValue-equals
]]
local function atom<T>(initialValue: T, equals: Equals<T>?): Atom<T>
	local get, set = signal(initialValue, equals)
	local function atomOper(...)
		return if select("#", ...) == 0 then get() else set((...))
	end
	return atomOper
end

--[[
	Creates a new read-only signal that is computed based on the values of
	other signals. The computed signal's value is automatically updated when a
	change is detected in any of its dependencies.

	@param getter Function that calculates the next value
	@return A function that returns the cached value
	@see https://github.com/littensy/charm?tab=readme-ov-file#computedgetter
]]
local function computed<T>(getter: (previousValue: T?) -> T): Getter<T>
	local this: ComputedNode = {
		flags = NONE,
		getter = noYield(getter),
	}

	local function readComputed(): T
		local flags = this.flags

		if
			bit32.btest(flags, DIRTY)
			or (bit32.btest(flags, PENDING) and (checkDirty(this.deps :: Link, this) or clearPending(this, flags)))
		then
			if updateComputed(this) then
				-- Notify subscribers if the value changed
				local subs = this.subs
				if subs then
					shallowPropagate(subs)
				end
			end
		elseif flags == NONE then
			-- First access should initialize the computed value
			this.flags = bit32.bor(MUTABLE, RECURSED_CHECK)

			local prevSub = setActiveSub(this)
			local success, result = pcall(this.getter)
			activeSub = prevSub

			this.flags = bit32.band(this.flags, bit32.bnot(RECURSED_CHECK))

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

	return readComputed
end

--[[
	Creates an effect that runs a callback in response to signal state changes.
	An effect tracks which signals are accessed during its execution, and runs
	the callback when those signals change.

	The effect callback may return a cleanup function, which gets called once,
	either before the effect re-runs or when it is disposed.

	If the effect is called within another effect, it will be disposed when the
	parent effect re-runs.

	@param fn Function to execute reactively
	@return A cleanup function that stops the effect
	@see https://github.com/littensy/charm?tab=readme-ov-file#effectcallback
]]
local function effect(fn: () -> ...Cleanup?): Cleanup
	local this: EffectNode = {
		fn = noYield(fn),
		flags = WATCHING,
		cleanups = {},
	}

	if activeSub and (flags.trackInnerEffects or activeSub.flags == NONE) then
		link(this, activeSub, 0)
	end

	local prevSub = setActiveSub(this)
	local success, result = pcall(this.fn)
	activeSub = prevSub

	if not success then
		error(result)
	elseif result then
		table.insert(this.cleanups, noYield(result))
	end

	return function()
		stopEffect(this)
	end
end

--[[
	Creates an effect scope that can capture reactive effects and computed
	signals created within it so that they can be disposed together.

	@param fn Function that creates effects within the scope
	@param detached If true, the scope will not be tracked by the parent effect/scope
	@return A cleanup function that stops all effects in the scope
	@see https://github.com/littensy/charm?tab=readme-ov-file#effectscopecallback-detached
]]
local function effectScope(fn: () -> ...Cleanup?, detached: boolean?): Cleanup
	local this: EffectScopeNode = {
		flags = NONE,
		cleanups = {},
	}

	if activeSub and not detached then
		link(this, activeSub, 0)
	end

	local prevSub = setActiveSub(this)
	local success, result = pcall(noYield(fn))
	activeSub = prevSub

	if not success then
		error(result)
	elseif result then
		table.insert(this.cleanups, noYield(result))
	end

	return function()
		stopEffect(this)
	end
end

--[[
	Allows you to manually trigger updates for downstream dependencies when
	you've directly mutated a signal's value without using the signal setter.

	@param fn A signal or function that accesses signals
	@see https://github.com/littensy/charm?tab=readme-ov-file#triggercallback
]]
local function trigger(fn: () -> ())
	local sub: ReactiveNode = {
		flags = WATCHING,
	}

	local prevSub = setActiveSub(sub)
	local success, result: any = pcall(noYield(fn))
	activeSub = prevSub

	if not success then
		error(result)
	end

	local link = sub.deps
	while link do
		local dep = link.dep
		link = unlink(link, sub)
		local subs = dep.subs
		if subs then
			sub.flags = NONE
			propagate(subs)
			shallowPropagate(subs)
		end
	end

	if batchDepth == 0 then
		flush()
	end
end

--[[
	Binds the cleanup function to the current active effect or effect scope. If
	there is no active effect, a warning is logged, unless `failSilently` is
	set to `true`.

	@param fn Function to run during cleanup
	@param failSilently If true, silences the warning when called outside an effect/scope
	@see https://github.com/littensy/charm?tab=readme-ov-file#oncleanupcallback-failsilently
]]
local function onCleanup(fn: Cleanup, failSilently: boolean?)
	if activeSub and (activeSub :: EffectNode).cleanups then
		table.insert((activeSub :: EffectNode).cleanups, noYield(fn))
	elseif not failSilently then
		warn(debug.traceback("onCleanup() can only be called inside an effect or a scope.", 2))
	end
end

--[[
	Runs the function without subscribing to signal updates and prevents the
	current effect or scope from tracking inner effects created within the
	function.

	To avoid tracking signals while still allowing inner effects to be tracked
	by parent effects/scopes, use `effectScope()` instead.

	@param fn A signal or function that accesses signals
	@param ...args Arguments to pass to the function
	@return Values returned by the function
	@see https://github.com/littensy/charm?tab=readme-ov-file#untrackedcallback
]]
local function untracked<Args..., Results...>(fn: (Args...) -> Results..., ...: Args...): Results...
	if activeSub then
		local prevSub = setActiveSub(nil)
		local results: { any } = { pcall(noYield(fn), ...) }
		activeSub = prevSub
		if not results[1] then
			error(results[2])
		end
		return unpack(results, 2)
	else
		return fn(...)
	end
end

--[[
	Combines multiple updates into a single "commit" that runs effects and
	computed signals after the provided callback finishes running.

	@param fn Function that updates signals
	@param ...args Arguments to pass to the function
	@return Values returned by the function
	@see https://github.com/littensy/charm?tab=readme-ov-file#batchcallback
]]
local function batch<Args..., Results...>(fn: (Args...) -> Results..., ...: Args...): Results...
	startBatch()
	local results: { any } = { pcall(noYield(fn), ...) }
	endBatch()
	if not results[1] then
		error(results[2])
	end
	return unpack(results, 2)
end

--[[
	Wraps a function in a computed signal if it is not already a reactive
	signal. Useful for memoizing a getter function without creating unnecessary
	nested signals.

	@param fn A signal or function that accesses signals
	@return `fn` wrapped in a computed signal if needed
]]
local function toComputed<T>(fn: Getter<T>): Getter<T>
	local name = debug.info(fn, "n")
	return if name == "readSignal" or name == "readComputed" or name == "atomOper" then fn else computed(fn)
end

--[[
	Creates an effect that runs the callback one immediately, and then again
	when the value returned by the getter changes. The callback receives the
	new value and the previous value as arguments.

	Effects created within the callback are cleaned up when the listener runs
	or the listener is disposed.

	@param getter A signal or function that accesses signals
	@param fn Function to run when the value changes
	@return A cleanup function that stops the effect
	@see https://github.com/littensy/charm?tab=readme-ov-file#listengetter-callback
]]
local function listen<T>(getter: Getter<T>, fn: (state: T, lastState: T?) -> ()): Cleanup
	local tracked = toComputed(getter)
	local current: T

	return effect(function()
		local previous = current
		current = tracked()
		untracked(fn, current, previous)
	end)
end

--[[
	Creates an effect that only runs the callback when the value returned by
	the getter changes. The callback receives the new value and the previous
	value as arguments.

	Effects created within the callback are cleaned up when the listener runs
	or the listener is disposed.

	@param getter A signal or function that accesses signals
	@param fn Function to run when the value changes
	@return A cleanup function that stops the effect
	@see https://github.com/littensy/charm?tab=readme-ov-file#subscribegetter-callback
]]
local function subscribe<T>(getter: Getter<T>, fn: (state: T, lastState: T) -> ()): Cleanup
	local tracked = toComputed(getter)
	local current: T
	local firstRun = true

	return effect(function()
		local previous = current
		current = tracked()
		if firstRun then
			firstRun = false
		else
			untracked(fn, current, previous)
		end
	end)
end

--[[
	Calls the callback function for each unique key in the table returned by the
	getter. The callback is called once for each key, and again when a new key
	is added.

	The callback may return a cleanup function, which will be called when the
	key is removed or the `observe()` effect is disposed. Effects created
	during the callback will also be bound to the lifetime of the key.

	@param getter A signal or function that returns a table
	@param fn Function that is called for each key added to the table
	@return A cleanup function that disposes scopes for all keys
	@see https://github.com/littensy/charm?tab=readme-ov-file#observegetter-callback
]]
local function observe<K, V>(getter: Getter<{ [K]: V }>, fn: (item: V, key: K) -> ...Cleanup?): Cleanup
	local innerScopes: { [K]: Cleanup } = {}
	local disposed = false

	local function updateScopes(data: { [K]: V })
		for key, dispose in innerScopes do
			if data[key] == nil then
				innerScopes[key] = nil
				dispose()
				if disposed then
					return
				end
			end
		end

		for key, value in data do
			if innerScopes[key] == nil then
				local disposeScope = effectScope(function()
					return fn(value, key)
				end, true)
				if disposed then
					return disposeScope()
				end
				innerScopes[key] = disposeScope
			end
		end
	end

	return effectScope(function()
		effect(function()
			-- Batch so that side effects run after all scopes are created.
			-- This ensures that a scope creating or removing items doesn't
			-- interfere with the current update cycle.
			batch(updateScopes, getter())
		end)

		return function()
			disposed = true
			for key, dispose in innerScopes do
				innerScopes[key] = nil
				dispose()
			end
		end
	end)
end

--[[
	Creates a new read-only signal that is computed by mapping over the entries
	of an existing atom. If the key is omitted from the mapper's return value,
	the original key is preserved.

	@param getter A signal or function that returns a table
	@param mapper Function that maps each entry from the source to a new entry in the mapped table
	@see https://github.com/littensy/charm?tab=readme-ov-file#mappedgetter-mapper
]]
local function mapped<KI, VI, KO, VO>(getter: Getter<{ [KI]: VI }>, mapper: (VI, KI) -> (VO, KO)): Getter<{ [KO]: VO }>
	local currentInput: { [KI]: VI } = {}
	local keyCache: { [KI]: KO } = {}

	local function map(value: VI, key: KI): (VO, KO)
		local prevSub = setActiveSub(nil)
		local success, valueOut, keyOut = pcall(mapper, value, key)
		activeSub = prevSub
		if not success then
			error(`mapped() transform function failed: {valueOut}`)
		end
		return valueOut, if keyOut == nil then key else keyOut :: any
	end

	return computed(function(previousOutput)
		local currentOutput: { [KO]: VO } = previousOutput or {}
		local previousInput = currentInput
		currentInput = getter()

		for keyIn in previousInput do
			if currentInput[keyIn] ~= nil then
				continue
			end

			local prevKeyOut = keyCache[keyIn]

			if prevKeyOut then
				if currentOutput == previousOutput then
					currentOutput = table.clone(currentOutput)
				end
				currentOutput[prevKeyOut] = nil
				keyCache[keyIn] = nil
			end
		end

		for keyIn, valueIn in currentInput do
			if valueIn == previousInput[keyIn] then
				continue
			end

			local valueOut, keyOut = map(valueIn, keyIn)

			if currentOutput[keyOut] ~= valueOut then
				if currentOutput == previousOutput then
					currentOutput = table.clone(currentOutput)
				end
				currentOutput[keyOut] = valueOut
				keyCache[keyIn] = keyOut
			end
		end

		return currentOutput
	end)
end

createReactiveSystem(update, notify, unwatched)

return {
	ReactiveFlags = system.ReactiveFlags,
	flags = flags,
	atom = atom,
	signal = signal,
	computed = computed,
	effect = effect,
	effectScope = effectScope,
	trigger = trigger,
	untracked = untracked,
	batch = batch,
	subscribe = subscribe,
	listen = listen,
	observe = observe,
	mapped = mapped :: (<KI, VI, KO, VO>(
		getter: Getter<{ [KI]: VI }>,
		mapper: (VI, KI) -> (VO, KO)
	) -> Getter<{ [KO]: VO }>) & (<K, VI, VO>(getter: Getter<{ [K]: VI }>, mapper: (VI, K) -> VO) -> Getter<{ [K]: VO }>),
	onCleanup = onCleanup,
	getActiveSub = getActiveSub,
	setActiveSub = setActiveSub,
	startBatch = startBatch,
	endBatch = endBatch,
}
