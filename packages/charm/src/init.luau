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
local MUTABLE = 0b000001 -- Can be written to (signal or computed)
local WATCHING = 0b000010 -- Notified for changes in dependencies (effects)
local RECURSED_CHECK = 0b000100 -- Being checked for circular dependencies
local RECURSED = 0b001000 -- Has been visited in a recursion check
local DIRTY = 0b010000 -- Value is outdated and needs recomputation
local PENDING = 0b100000 -- Might be dirty, pending verification

-- Global version counter for dependency link deduplication. Incremented at the
-- start of each effect/computed run to ensure links created in the same cycle
-- are deduplicated.
local cycle = 0
-- Effects runs are queued to prevent redundant executions when multiple
-- signals update in the same batch.
local queued: { EffectNode } = {}
local queuedLength = 0
local notifyIndex = 0
-- Batch operations group multiple updates together, deferring effect runs
-- until the batch completes. Effects only run when the outermost batch ends.
local batchDepth = 0
-- Tracks the currently active effect or computed signal during execution.
-- Dependencies accessed during this time will link to the active subscriber.
local activeSub: ReactiveNode?

local function isO2(): boolean
	return debug.info(1, "f") ~= isO2
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
	Wraps a user-created function to prevent yielding when in strict mode. To
	shorten error stack traces, only functions created outside of this module
	are wrapped.
]]
local function wrapUserSpace<Args..., Results...>(callback: (Args...) -> Results...): (Args...) -> Results...
	if not flags.strict then
		return callback
	end

	-- If the sources match, the function was created in this module
	if debug.info(1, "s") == debug.info(callback, "s") then
		return callback
	end

	local handler = function(thread: thread, ok: boolean, ...: Results...): Results...
		if not ok then
			local err = (...)
			if type(err) == "string" then
				error(debug.traceback(thread, err), 0)
			else
				error(tostring(err), 0)
			end
		elseif coroutine.status(thread) ~= "dead" then
			error(debug.traceback(thread, "Attempted to yield in an effect or scope"), 0)
		else
			return ...
		end
	end

	return function(...: Args...): Results...
		local thread = coroutine.create(callback)
		return handler(thread, coroutine.resume(thread, ...))
	end
end

--[[
	Recursively freezes a table and all nested tables to enforce immutability.
	Tables with metatables are skipped, as they are assumed to be mutable.
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
]]
local function getActiveSub(): ReactiveNode?
	return activeSub
end

--[[
	Sets the currently active subscriber (effect or computed node) and returns
	the previous subscriber.
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
	thrown during cleanup are caught and logged in a single error after all
	cleanups are complete.
]]
local function runCleanups(cleanups: { Cleanup })
	local hasErrors = false
	local errors: { string } = {}

	for index, cleanup in cleanups do
		cleanups[index] = nil

		local prevSub = setActiveSub(nil)
		local success, err = pcall(cleanup)
		activeSub = prevSub

		if not success then
			hasErrors = true
			table.insert(errors, tostring(err))
		end
	end

	if hasErrors then
		error(`Errors occurred during effect cleanup:\n\n{table.concat(errors, "\n\n")}`, 0)
	end
end

--[[
	Checks if the effect node needs to run based on its flags and dependencies.
	Effects run if they are marked dirty or pending with dirty dependencies.
]]
local function run(effect: EffectNode)
	local effectFlags = effect.flags

	if
		bit32.btest(effectFlags, DIRTY)
		or (bit32.btest(effectFlags, PENDING) and checkDirty(effect.deps :: Link, effect))
	then
		runCleanups(effect.cleanups)

		-- Cancel the run if the effect was disposed during cleanup
		if effect.flags == NONE then
			return
		end

		cycle += 1
		effect.depsTail = nil
		effect.flags = WATCHING

		local prevSub = setActiveSub(effect)
		local success, result = pcall(effect.fn)
		activeSub = prevSub

		purgeDeps(effect)

		if success and result then
			table.insert(effect.cleanups, wrapUserSpace(result))
		elseif not success then
			error(result, 0)
		end

		-- If the effect was disposed during execution but before a cleanup was
		-- was registered, run the cleanups that would have been missed
		if effect.flags == NONE then
			runCleanups(effect.cleanups)
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
	-- Bail out early if a flush is already in progress to allow effects to
	-- complete before the next effect runs
	if batchDepth ~= 0 or notifyIndex ~= 0 then
		return
	end

	local success, err = pcall(function()
		while notifyIndex < queuedLength do
			notifyIndex += 1
			local effect = queued[notifyIndex] :: EffectNode
			queued[notifyIndex] = nil
			run(effect)
		end
	end)

	-- Skip over any remaining queued effects that were not run due to an error
	while notifyIndex < queuedLength do
		notifyIndex += 1
		local effect = queued[notifyIndex] :: EffectNode
		queued[notifyIndex] = nil
		effect.flags = bit32.bor(effect.flags, bit32.bor(WATCHING, RECURSED))
	end

	notifyIndex = 0
	queuedLength = 0

	if not success then
		error(err, 0)
	end
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
	flush()
end

--[[
	Updates a computed signal by re-evaluating its getter function. Returns
	whether the computed value changed.
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
		error(newValue, 0)
	end
end

--[[
	Updates a signal by applying its pending value. Returns whether the
	signal's value changed.
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
	Clears all dependencies and subscribers from the effect node. After calling
	this, the node will no longer be subscribed to any dependencies and will be
	inactive, with all cleanup functions run and resources released.
]]
local function stopEffect(effect: EffectScopeNode)
	effect.depsTail = nil
	effect.flags = NONE

	purgeDeps(effect)

	-- Unlink from the parent effect, if it exists
	local sub = effect.subs
	if sub then
		unlink(sub, effect)
	end

	runCleanups(effect.cleanups)
end

--[[
	Updates a signal or computed value and returns whether the value changed.
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
]]
local function notify(effect: ReactiveNode)
	local startIndex = queuedLength + 1

	-- Collect inner effects in a chain
	repeat
		queuedLength += 1
		queued[queuedLength] = effect :: EffectNode

		-- Mark as not watching to prevent duplicates in the same flush
		effect.flags = bit32.band(effect.flags, bit32.bnot(WATCHING))

		-- Traverse to the parent effect, if it exists and is not queued, to
		-- ensure it gets notified before the child effect
		effect = (effect.subs and effect.subs.sub) :: EffectNode

		if not effect or bit32.band(effect.flags, WATCHING) == 0 then
			break
		end
	until false

	local endIndex = queuedLength

	-- Reverse the collected effects since they were collected from child to
	-- parent, but should be notified from parent to child
	while startIndex < endIndex do
		queued[startIndex], queued[endIndex] = queued[endIndex], queued[startIndex]
		startIndex += 1
		endIndex -= 1
	end
end

--[[
	Called when a node is not being watched by any subscribers. Cleans up the
	node's dependencies and performs the necessary cleanup operations:

	- Computed signals: Unlink dependencies and mark as dirty for potential
	future updates
	- Effects/scopes: Perform full cleanup to free resources
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
	local node: SignalNode = {
		currentValue = initialValue,
		pendingValue = initialValue,
		flags = MUTABLE,
	}

	if flags.frozen then
		deepFreeze(initialValue)
	end

	local function signalGetter(): T
		-- Check if the signal has a pending update that needs to be applied
		if bit32.btest(node.flags, DIRTY) then
			if updateSignal(node) then
				local subs = node.subs
				if subs then
					shallowPropagate(subs)
				end
			end
		end

		-- Register this signal as a dependency of the first subscriber in the
		-- chain that is a computed signal or an effect
		local sub = activeSub
		while sub do
			if bit32.btest(sub.flags, bit32.bor(MUTABLE, WATCHING)) then
				link(node, sub, cycle)
				break
			end
			local subs = sub.subs
			sub = if subs then subs.sub else nil
		end

		return node.currentValue
	end

	local function signalSetter(update: Update<T>): T
		local value: T

		-- Determine the new value based on whether the update is a function or
		-- a direct value
		if type(update) == "function" then
			local prevSub = setActiveSub(nil)
			local success, result = pcall(wrapUserSpace(update), node.pendingValue)
			activeSub = prevSub

			if success then
				value = result
			else
				error(result, 2)
			end
		else
			value = update
		end

		-- Check if the new value is different from the pending value
		if if equals then not equals(node.pendingValue, value) else node.pendingValue ~= value then
			if flags.frozen then
				deepFreeze(value)
			end

			node.pendingValue = value
			node.flags = bit32.bor(MUTABLE, DIRTY)

			local subs = node.subs
			if subs then
				propagate(subs)
				flush()
			end
		end

		return node.pendingValue
	end

	return signalGetter, signalSetter
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
	local node: ComputedNode = {
		flags = NONE,
		getter = wrapUserSpace(getter),
	}

	local function computedOper(): T
		local nodeFlags = node.flags

		if bit32.btest(nodeFlags, DIRTY) then
			if updateComputed(node) then
				local subs = node.subs
				if subs then
					shallowPropagate(subs)
				end
			end
		elseif bit32.btest(nodeFlags, PENDING) then
			if checkDirty(node.deps :: Link, node) then
				if updateComputed(node) then
					local subs = node.subs
					if subs then
						shallowPropagate(subs)
					end
				end
			else
				node.flags = bit32.band(nodeFlags, bit32.bnot(PENDING))
			end
		elseif nodeFlags == NONE then
			-- First access should initialize the computed value
			node.flags = bit32.bor(MUTABLE, RECURSED_CHECK)

			local prevSub = setActiveSub(node)
			local success, result = pcall(node.getter)
			activeSub = prevSub

			node.flags = bit32.band(node.flags, bit32.bnot(RECURSED_CHECK))

			if success then
				node.value = result
			else
				error(result, 2)
			end
		end

		if activeSub then
			link(node, activeSub, cycle)
		end

		return node.value
	end

	return computedOper
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
	local node: EffectNode = {
		fn = wrapUserSpace(fn),
		flags = WATCHING,
		cleanups = {},
	}

	-- Inner effects are tracked as a dependency of the parent effect, so that
	-- they can be automatically cleaned up when the parent effect re-runs, and
	-- to ensure the correct execution order when nested effects are notified
	if activeSub and (flags.trackInnerEffects or activeSub.flags == NONE) then
		link(node, activeSub, 0)
	end

	-- Start a batch so that the effect can register a cleanup function before
	-- it can receive notifications, ensuring the cleanup always runs
	startBatch()

	local prevSub = setActiveSub(node)
	local success, result = pcall(node.fn)
	activeSub = prevSub

	if success and result then
		table.insert(node.cleanups, wrapUserSpace(result))
	elseif not success then
		endBatch()
		error(result, 2)
	end

	endBatch()

	return function()
		stopEffect(node)
	end
end

--[[
	Creates an effect scope that can capture reactive effects and computed
	signals created within it so that they can be disposed together.

	@param fn Function that creates effects within the scope
	@param detached If true, the scope will not be tracked by the parent effect or scope
	@return A cleanup function that stops all effects in the scope
	@see https://github.com/littensy/charm?tab=readme-ov-file#effectscopecallback-detached
]]
local function effectScope(fn: () -> ...Cleanup?, detached: boolean?): Cleanup
	local node: EffectScopeNode = {
		flags = NONE,
		cleanups = {},
	}

	-- Inner effect scopes are tracked as a dependency of the parent effect
	if activeSub and not detached then
		link(node, activeSub, 0)
	end

	local prevSub = setActiveSub(node)
	local success, result = pcall(wrapUserSpace(fn))
	activeSub = prevSub

	if success and result then
		table.insert(node.cleanups, wrapUserSpace(result))
	elseif not success then
		error(result, 2)
	end

	return function()
		stopEffect(node)
	end
end

--[[
	Allows you to manually trigger updates for downstream dependencies when
	you've directly mutated a signal's value without using the signal setter.

	@param fn A signal or function that accesses signals
	@see https://github.com/littensy/charm?tab=readme-ov-file#triggercallback
]]
local function trigger(fn: () -> ...any)
	local sub: ReactiveNode = {
		flags = WATCHING,
	}

	local prevSub = setActiveSub(sub)
	local success, err = pcall(wrapUserSpace(fn))
	activeSub = prevSub
	sub.flags = NONE

	local currentLink = sub.deps
	while currentLink do
		local dep = currentLink.dep
		local subs = dep.subs
		currentLink = unlink(currentLink, sub)
		if subs then
			propagate(subs)
			shallowPropagate(subs)
		end
	end

	flush()

	if not success then
		error(err, 2)
	end
end

--[[
	Binds the cleanup function to the current active effect or effect scope. If
	there is no active effect, a warning is logged, unless `failSilently` is
	set to `true`.

	@param fn Function to run during cleanup
	@param failSilently If true, silences the warning when called outside an effect or scope
	@see https://github.com/littensy/charm?tab=readme-ov-file#oncleanupcallback-failsilently
]]
local function onCleanup(fn: Cleanup, failSilently: boolean?)
	if activeSub and (activeSub :: EffectNode).cleanups then
		table.insert((activeSub :: EffectNode).cleanups, wrapUserSpace(fn))
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
		local results: { any } = { pcall(wrapUserSpace(fn), ...) }
		activeSub = prevSub

		if not results[1] then
			error(results[2], 2)
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
	local results: { any } = { pcall(wrapUserSpace(fn), ...) }
	endBatch()

	if not results[1] then
		error(results[2], 2)
	end

	return unpack(results, 2)
end

--[[
	Returns true if the given function is a signal getter, computed signal, or
	atom function. Used for determining whether a function should be wrapped in
	a computed signal so that it can be memoized in `listen()` and `subscribe()`.
]]
local function isSignal(fn: Getter<any>): boolean
	local name = debug.info(fn, "n")
	return name == "signalGetter" or name == "computedOper" or name == "atomOper"
end

--[[
	Creates an effect that runs the callback once immediately, and then again
	when the value returned by the getter changes. The callback receives the
	new value and the previous value as arguments.

	@param getter A signal or function that accesses signals
	@param callback Function to run when the value changes
	@return A cleanup function that stops the effect
	@see https://github.com/littensy/charm?tab=readme-ov-file#listengetter-callback
]]
local function listen<T>(getter: Getter<T>, callback: (state: T, lastState: T?) -> ()): Cleanup
	local tracked: Getter<T> = if isSignal(getter) then getter else computed(getter :: (T?) -> T)
	local current: T

	return effect(function()
		local previous = current
		current = tracked()
		untracked(callback, current, previous)
	end)
end

--[[
	Creates an effect that only runs the callback when the value returned by
	the getter changes. The callback receives the new value and the previous
	value as arguments.

	@param getter A signal or function that accesses signals
	@param callback Function to run when the value changes
	@return A cleanup function that stops the effect
	@see https://github.com/littensy/charm?tab=readme-ov-file#subscribegetter-callback
]]
local function subscribe<T>(getter: Getter<T>, callback: (state: T, lastState: T) -> ()): Cleanup
	local tracked: Getter<T> = if isSignal(getter) then getter else computed(getter :: (T?) -> T)
	local current: T
	local firstRun = true

	return effect(function()
		local previous = current
		current = tracked()
		if firstRun then
			firstRun = false
		else
			untracked(callback, current, previous)
		end
	end)
end

--[[
	Calls the callback function for each unique key in the table returned by
	the getter. The callback is called once for each key, and again when a new
	key is added.

	The callback may return a cleanup function, which will be called when the
	key is removed or the `observe()` effect is disposed. Effects created
	during the callback will also be bound to the lifetime of the key.

	@param getter A signal or function that returns a table
	@param callback Function that is called for each key added to the table
	@return A cleanup function that disposes scopes for all keys
	@see https://github.com/littensy/charm?tab=readme-ov-file#observegetter-callback
]]
local function observe<K, V>(getter: Getter<{ [K]: V }>, callback: (item: V, key: K) -> ...Cleanup?): Cleanup
	getter = wrapUserSpace(getter)
	callback = wrapUserSpace(callback)

	local scopes: { [K]: Cleanup } = {}
	local stopObserving = false

	local function updateScopes(data: { [K]: V })
		for key, dispose in scopes do
			if data[key] == nil then
				scopes[key] = nil
				dispose()
				if stopObserving then
					return
				end
			end
		end

		for key, value in data do
			if scopes[key] == nil then
				local dispose = effectScope(function()
					return callback(value, key)
				end, true)
				if stopObserving then
					dispose()
					return
				end
				scopes[key] = dispose
			end
		end
	end

	return effectScope(function()
		effect(function()
			-- Wrap in untracked so that calling fn inside updateScopes does
			-- not register dependencies to this effect
			untracked(updateScopes, getter())
		end)

		return function()
			stopObserving = true
			for key, dispose in scopes do
				scopes[key] = nil
				dispose()
			end
		end
	end)
end

--[[
	Creates a new read-only signal that is computed by mapping over the entries
	of the source table. If the key is omitted from the transform function's
	return value, the original key is preserved.

	This function is optimized to minimize unnecessary updates by only calling
	the transform function for entries that have changed since the last run.

	@param getter A signal or function that returns a table
	@param transform Function that maps each entry from the source to a new entry in the mapped table
	@see https://github.com/littensy/charm?tab=readme-ov-file#mappedgetter-transform
]]
local function mapped<KI, VI, KO, VO>(getter: Getter<{ [KI]: VI }>, transform: (VI, KI) -> (VO, KO)): Getter<{ [KO]: VO }>
	getter = wrapUserSpace(getter)
	transform = wrapUserSpace(transform)

	local nextInput: { [KI]: VI } = {}
	local keyMap: { [KI]: KO } = {}

	return computed(function(lastOutput: { [KO]: VO }?): { [KO]: VO }
		local nextOutput: { [KO]: VO } = lastOutput or {}
		local prevInput = nextInput
		nextInput = getter()

		-- For keys that were removed from the input, remove the corresponding
		-- keys from the output.
		for keyIn in prevInput do
			if nextInput[keyIn] ~= nil then
				continue
			end

			local keyOut = keyMap[keyIn]

			if keyOut ~= nil then
				if nextOutput == lastOutput then
					nextOutput = table.clone(nextOutput)
				end
				nextOutput[keyOut] = nil
				keyMap[keyIn] = nil
			end
		end

		-- For keys that are new or changed, pass it to the mapper and update
		-- the output. If the mapper returns a new key that is different from
		-- the previous call, the old mapped key should be removed from the
		-- output.
		for keyIn, nextValueIn in nextInput do
			if nextValueIn == prevInput[keyIn] then
				continue
			end

			local nextValueOut, keyOutOrNil = transform(nextValueIn, keyIn)
			local nextKeyOut: KO = if keyOutOrNil ~= nil then keyOutOrNil else keyIn
			local prevKeyOut = keyMap[keyIn]

			if prevKeyOut ~= nil and prevKeyOut ~= nextKeyOut then
				if nextOutput == lastOutput then
					nextOutput = table.clone(nextOutput)
				end
				nextOutput[prevKeyOut] = nil
				nextOutput[nextKeyOut] = nextValueOut
				keyMap[keyIn] = nextKeyOut
			elseif nextOutput[nextKeyOut] ~= nextValueOut then
				if nextOutput == lastOutput then
					nextOutput = table.clone(nextOutput)
				end
				nextOutput[nextKeyOut] = nextValueOut
				keyMap[keyIn] = nextKeyOut
			end
		end

		return nextOutput
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
		transform: (VI, KI) -> (VO, KO)
	) -> Getter<{ [KO]: VO }>) & (<K, VI, VO>(getter: Getter<{ [K]: VI }>, transform: (VI, K) -> VO) -> Getter<{ [K]: VO }>),
	onCleanup = onCleanup,
	getActiveSub = getActiveSub,
	setActiveSub = setActiveSub,
	startBatch = startBatch,
	endBatch = endBatch,
}
