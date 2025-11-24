local system = require("@self/system")

export type ReactiveFlags = system.ReactiveFlags
export type ReactiveNode = system.ReactiveNode
export type Link = system.Link

export type Atom<T = any> = (...((T) -> T) | T) -> T

type ReactiveProxyApi<T = {}> = {
	value: T,
	track: () -> (),
	set: (T | (T) -> ()?) -> (),
}

type ReactiveProxyProps<T = {}> = {
	__target: T,
	__signals: { [unknown]: () -> unknown },
}

export type ReactiveProxy<T = {}> = T & typeof(setmetatable({} :: ReactiveProxyProps<T>, {} :: ReactiveProxyApi<T>))

type EffectScopeNode = ReactiveNode & {
	cleanups: { () -> () },
}

type EffectNode = ReactiveNode & {
	fn: () -> ...(() -> ())?,
	cleanups: { () -> () },
}

type ComputedNode<T = any> = ReactiveNode & {
	value: T?,
	getter: (previousValue: T?) -> T,
}

type SignalNode<T = any> = ReactiveNode & {
	currentValue: T,
	pendingValue: T,
}

local NONE = 0b0000000
local MUTABLE = 0b0000001
local WATCHING = 0b0000010
local RECURSED_CHECK = 0b0000100
local DIRTY = 0b0010000
local PENDING = 0b0100000
local PEEKING = 0b1000000

local function inlineTest(): string
	return debug.info(1, "n")
end

local flags = {
	--[[
		Enforces synchronous, non-yielding behavior in signals and effects.
		Also enables state validation in Charm Sync to catch sync errors early.
		Enabled if the optimization level is below 2, which is true in studio.
	]]
	strict = inlineTest() == "inlineTest",
	--[[
		Enforces immutability of tables by deep-freezing table values. Enabled
		if the optimization level is below 2, which is true in studio.
	]]
	frozen = inlineTest() == "inlineTest",
	--[[
		Whether parent effects should track inner effects and clean them up
		when the parent effect re-runs. This is usually desirable, but can be
		disabled to revert to the old behavior. Defaults to `true`.
	]]
	trackInnerEffects = true,
}

local link: (dep: ReactiveNode, sub: ReactiveNode, version: number) -> ()
local unlink: (link: Link, sub: ReactiveNode?) -> Link?
local propagate: (link: Link) -> ()
local checkDirty: (link: Link, sub: ReactiveNode) -> boolean
local shallowPropagate: (link: Link) -> ()

local cycle = 0
local batchDepth = 0
local notifyIndex = 0
local queued: { EffectNode? } = {}
local queuedLength = 0
local activeSub: ReactiveNode?

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

local function deepFreeze(object: any)
	if type(object) == "table" and not table.isfrozen(object) and getmetatable(object) == nil then
		table.freeze(object)
		for _, value in object do
			deepFreeze(value)
		end
	end
end

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

local function runCleanups(effect: EffectScopeNode)
	local cleanups = effect.cleanups
	for key, cleanup in cleanups do
		local prevSub = setActiveSub(nil)
		local success, result: any = pcall(cleanup)
		activeSub = prevSub
		cleanups[key] = nil
		if not success then
			warn("An error occurred during effect cleanup:", result)
		end
	end
end

local function run(e: EffectNode)
	local flags = e.flags
	if bit32.btest(flags, DIRTY) or (bit32.btest(flags, PENDING) and checkDirty(e.deps :: Link, e)) then
		runCleanups(e)
		cycle += 1
		e.depsTail = nil
		e.flags = bit32.bor(WATCHING, RECURSED_CHECK)
		local prevSub = setActiveSub(e)
		local success, result = pcall(e.fn)
		activeSub = prevSub
		e.flags = bit32.band(e.flags, bit32.bnot(RECURSED_CHECK))
		purgeDeps(e)
		if not success then
			error(result)
		elseif result then
			table.insert(e.cleanups, noYield(result))
		end
	else
		e.flags = WATCHING
	end
end

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

local function startBatch()
	batchDepth += 1
end

local function endBatch()
	batchDepth -= 1
	if batchDepth == 0 then
		flush()
	end
end

local function updateComputed(c: ComputedNode): boolean
	cycle += 1
	c.depsTail = nil
	c.flags = bit32.bor(MUTABLE, RECURSED_CHECK)
	local prevSub = setActiveSub(c)
	local oldValue = c.value
	local success, result = pcall(c.getter, oldValue)
	activeSub = prevSub
	c.flags = bit32.band(c.flags, bit32.bnot(RECURSED_CHECK))
	purgeDeps(c)
	if not success then
		error(result)
	end
	if oldValue ~= result then
		c.value = result
		return true
	else
		return false
	end
end

local function updateSignal(s: SignalNode): boolean
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

local function computedOper<T>(this: ComputedNode<T>): () -> T
	local function computedGetter(): T
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
	return computedGetter
end

local function signalOper<T>(
	this: SignalNode<T>,
	equals: ((current: T, incoming: T) -> boolean)?
): (() -> T, (((T) -> T) | T) -> T)
	local function signalSetter(update: ((T) -> T) | T): T
		local value: T
		if type(update) == "function" then
			local prevSub = setActiveSub(nil)
			local success, result = pcall(noYield(update), this.pendingValue)
			activeSub = prevSub
			if not success then
				error(result)
			end
			value = result
		else
			value = update
		end
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

	local function signalGetter(): T
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
			sub = if subs then subs.sub else nil
		end
		return this.currentValue
	end

	return signalGetter, signalSetter
end

local function effectOper(this: EffectScopeNode): () -> ()
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

local function update(node: ReactiveNode): boolean
	if node.depsTail then
		return updateComputed(node :: ComputedNode)
	else
		return updateSignal(node :: SignalNode)
	end
end

local function notify(effect: ReactiveNode)
	local insertIndex = queuedLength
	local firstInsertedIndex = insertIndex

	repeat
		effect.flags = bit32.band(effect.flags, bit32.bnot(WATCHING))
		queued[insertIndex] = effect :: EffectNode
		insertIndex += 1
		effect = (effect.subs and effect.subs.sub) :: EffectNode
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
end

local function unwatched(node: ReactiveNode)
	if bit32.band(node.flags, MUTABLE) == 0 then
		effectOper(node :: EffectScopeNode)()
	elseif node.depsTail then
		node.depsTail = nil
		node.flags = bit32.bor(MUTABLE, DIRTY)
		purgeDeps(node)
	end
end

--[[
	Creates a reactive signal that stores a value and notifies subscribers when
	the value changes. The signal provides both a getter and a setter.

	@param initialValue The initial value of the signal.
	@param equals A comparator function to determine if the signal's value has changed.
	@return A function to get the current value of the signal.
	@return A function to set a new value and notify subscribers.
	@see https://github.com/littensy/charm?tab=readme-ov-file#signalinitialValue-equals
]]
local function signal<T>(
	initialValue: T,
	equals: ((current: T, incoming: T) -> boolean)?
): (() -> T, (((T) -> T) | T) -> T)
	if flags.frozen then
		deepFreeze(initialValue)
	end
	return signalOper({
		currentValue = initialValue,
		pendingValue = initialValue,
		flags = MUTABLE,
	}, equals)
end

--[[
	Creates a reactive atom that acts as both a signal getter and setter.
	Calling the atom with an argument sets its value, while calling it with no
	arguments returns its current value.

	@param initialValue The initial value of the atom. If empty, the atom's value will be `nil`.
	@param equals A comparator function to determine if the atom's value has changed.
	@see https://github.com/littensy/charm?tab=readme-ov-file#atominitialValue-equals
]]
local function atom<T>(initialValue: T, equals: ((current: T, incoming: T) -> boolean)?): Atom<T>
	local getter, setter = signal(initialValue, equals)
	local function atomOper(...)
		return if select("#", ...) == 0 then getter() else setter((...))
	end
	return atomOper
end

--[[
	Creates a new read-only signal that is computed based on the values of
	other signals. The computed signal's value is automatically updated when a
	change is detected in any of its dependencies.

	@param getter A function that produces the next value.
	@see https://github.com/littensy/charm?tab=readme-ov-file#computedgetter
]]
local function computed<T>(getter: (previousValue: T?) -> T): () -> T
	return computedOper({
		flags = NONE,
		getter = noYield(getter),
	})
end

--[[
	Creates an effect that runs a callback in response to signal state changes.
	An effect tracks which signals are accessed during its execution, and runs
	the callback when those signals change.

	The effect callback may return a cleanup function, which gets called once,
	either before the effect re-runs or when it is disposed.

	If the effect is called within another effect, it will be disposed when the
	parent effect re-runs.

	@param fn The function to run when dependencies change.
	@return A function for disposing the effect.
	@see https://github.com/littensy/charm?tab=readme-ov-file#effectcallback
]]
local function effect(fn: () -> ...(() -> ())?): () -> ()
	local e: EffectNode = {
		fn = noYield(fn),
		flags = bit32.bor(WATCHING, RECURSED_CHECK),
		cleanups = {},
	}
	local prevSub = setActiveSub(e)
	if prevSub and (flags.trackInnerEffects or prevSub.flags == NONE) then
		link(e, prevSub, 0)
	end
	local success, result = pcall(e.fn)
	activeSub = prevSub
	e.flags = bit32.band(e.flags, bit32.bnot(RECURSED_CHECK))
	if not success then
		error(result)
	elseif result then
		table.insert(e.cleanups, noYield(result))
	end
	return effectOper(e)
end

--[[
	Creates an effect scope that can capture reactive effects and computed
	signals created within it so that they can be disposed together.

	@param fn A function that may create reactive effects.
	@param detached If true, the scope will not be automatically disposed of when the parent scope is disposed. Defaults to false.
	@return A function for disposing all effects created within the scope.
	@see https://github.com/littensy/charm?tab=readme-ov-file#effectscopecallback-detached
]]
local function effectScope(fn: () -> ...(() -> ())?, detached: boolean?): () -> ()
	local e: EffectScopeNode = {
		flags = NONE,
		cleanups = {},
	}
	local prevSub = setActiveSub(e)
	if prevSub and not detached then
		link(e, prevSub, 0)
	end
	local success, result = pcall(noYield(fn))
	activeSub = prevSub
	if not success then
		error(result)
	elseif result then
		table.insert(e.cleanups, noYield(result))
	end
	return effectOper(e)
end

--[[
	Allows you to manually trigger updates for downstream dependencies when
	you've directly mutated a signal's value without using the signal setter.

	@param fn The dependency or a function that calls multiple dependencies.
	@see https://github.com/littensy/charm?tab=readme-ov-file#triggercallback
]]
local function trigger(fn: () -> ())
	local sub: ReactiveNode = {
		flags = WATCHING,
	}
	local prevSub = setActiveSub(sub)
	local success, result: any = pcall(noYield(fn))
	activeSub = prevSub
	while sub.deps do
		local link = sub.deps :: Link
		local dep = link.dep
		unlink(link, sub)
		if dep.subs then
			propagate(dep.subs)
			shallowPropagate(dep.subs)
		end
	end
	if batchDepth == 0 then
		flush()
	end
	if not success then
		error(result)
	end
end

--[[
	Binds the cleanup function to the current active effect or effect scope. If
	there is no active effect, a warning is logged, unless `failSilently` is
	set to `true`.

	@param fn The cleanup function to register.
	@param failSilently If `true`, suppresses the warning when there is no active effect or scope. Defaults to `false`.
	@see https://github.com/littensy/charm?tab=readme-ov-file#oncleanupcallback-failsilently
]]
local function onCleanup(fn: () -> (), failSilently: boolean?)
	if activeSub and (activeSub :: EffectNode).cleanups then
		table.insert((activeSub :: EffectNode).cleanups, noYield(fn))
	elseif not failSilently then
		warn(debug.traceback("onCleanup() can only be called inside an effect or a scope.", 2))
	end
end

--[[
	Runs the function without subscribing to signal updates or capturing inner
	effects in the parent effect or scope.

	For an alternative that still cleans up inner effects, use `peek` instead.

	@param fn A function that may read signals or create effects.
	@param ...args Arguments to pass to the function.
	@return The return value of the function.
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
	Runs the function without subscribing to signal updates, but still captures
	inner effects so that they dispose with the parent effect.

	To avoid capturing inner effects, use `untracked` instead.

	@param fn A function that may read signals.
	@param ...args Arguments to pass to the function.
	@return The return value of the function.
	@see https://github.com/littensy/charm?tab=readme-ov-file#peekcallback
]]
local function peek<Args..., Results...>(fn: (Args...) -> Results..., ...: Args...): Results...
	if
		activeSub
		and bit32.band(activeSub.flags, PEEKING) == 0
		and bit32.btest(activeSub.flags, bit32.bor(WATCHING, MUTABLE))
	then
		activeSub.flags = bit32.bor(activeSub.flags, PEEKING)
		local results: { any } = { pcall(noYield(fn), ...) }
		activeSub.flags = bit32.band(activeSub.flags, bit32.bnot(PEEKING))
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

	@param fn A function that performs multiple updates.
	@param ...args Arguments to pass to the function.
	@return The return value of the function.
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
	Converts a non-signal into a computed signal. If the function is already a
	signal, it is returned as-is. Useful for memoizing a getter function
	without creating unnecessary nested signals.

	@param fn A function that returns the value to track.
	@return A computed signal that tracks the value returned by the getter.
]]
local function toSignal<T>(fn: () -> T): () -> T
	local name = debug.info(fn, "n")
	return if name == "signalGetter" or name == "computedGetter" or name == "atomOper" then fn else computed(fn)
end

--[[
	Creates an effect that runs the callback one immediately, and then again
	when the value returned by the getter changes. The callback receives the new
	value and the previous value as arguments.

	Effects created within the callback are cleaned up when the listener runs
	or the listener is disposed.

	@param getter A function that returns the value to watch.
	@param fn The function to run when the value changes.
	@return A function for disposing the effect.
	@see https://github.com/littensy/charm?tab=readme-ov-file#listengetter-callback
]]
local function listen<T>(getter: () -> T, fn: (state: T, previous: T?) -> ()): () -> ()
	local tracked = toSignal(getter)
	local current: T

	return effect(function()
		local previous = current
		current = tracked()
		peek(fn, current, previous)
	end)
end

--[[
	Creates an effect that only runs the callback when the value returned by the
	getter changes. The callback receives the new value and the previous value
	as arguments.

	Effects created within the callback are cleaned up when the listener runs
	or the listener is disposed.

	@param getter A function that returns the value to watch.
	@param fn The function to run when the value changes.
	@return A function for disposing the effect.
	@see https://github.com/littensy/charm?tab=readme-ov-file#subscribegetter-callback
]]
local function subscribe<T>(getter: () -> T, fn: (state: T, lastState: T) -> ()): () -> ()
	local tracked = toSignal(getter)
	local current: T
	local firstRun = true

	return effect(function()
		local previous = current
		current = tracked()
		if firstRun then
			firstRun = false
		else
			peek(fn, current, previous)
		end
	end)
end

--[[
	Disables recursive checks for the current effect or computed signal. Useful
	for effects that intentionally update signals they depend on.

	@example
	```luau
	effect(function()
	    recursive()
	    setCount(getCount() + 1)
	end)
	```
]]
local function recursive()
	if activeSub then
		activeSub.flags = bit32.band(activeSub.flags, bit32.bnot(RECURSED_CHECK))
	else
		warn(debug.traceback("recursive() can only be called inside an effect or computed signal.", 2))
	end
end

--[[
	Calls the callback function for each unique key in the table returned by the
	getter. The callback is called once for each key, and again when a new key
	is added.

	The callback may return a cleanup function, which will be called when the
	key is removed or the `observe()` effect is disposed. Effects created
	during the callback will also be bound to the lifetime of the key.

	@param getter A function that returns the table to observe.
	@param fn A function that is called for each key in the table.
	@return A function for disposing the observer.
	@see https://github.com/littensy/charm?tab=readme-ov-file#observegetter-callback
]]
local function observe<K, V>(getter: () -> { [K]: V }, fn: (item: V, key: K) -> ...(() -> ())?): () -> ()
	local innerScopes: { [K]: () -> () } = {}
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
			-- Allow recursive updates in case the callback creates or removes
			-- items in the observed table.
			recursive()
			-- Batch so that side effects run after all scopes are created.
			-- This ensures that a scope creating or removing items doesn't
			-- interfere with the current update cycle.
			batch(updateScopes, getter())
		end)

		return function()
			if disposed then
				return
			end
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

	@param getter Returns the table to map over.
	@param mapper Transforms each value-key pair from the source into a new value or value-key pair for the resulting table.
	@see https://github.com/littensy/charm?tab=readme-ov-file#mappedgetter-mapper
]]
local function mapped<KI, VI, KO, VO>(getter: () -> { [KI]: VI }, mapper: (item: VI, key: KI) -> (VO, KO)): () -> { [KO]: VO }
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

--[[
	Creates a deep reactive value that tracks properties when they're accessed.
	Returns a proxy object that subscribes to changes on any nested property
	you read, and a function for mutating the original table.

	@example
	```luau
	local users, setUsers = reactive({
		{ name = "John", surname = "Doe" },
	})

	effect(function()
		print(`{users[1].name} {users[1].surname}`)
	end)

	setUsers(function(state)
		state[1].name = "Jane"
		state[1].surname = "Smith"
	end)
	```

	@param initialValue The value to make deeply reactive.
	@return A proxy table that tracks reads to nested properties.
	@return A function for updating the original table.
	@see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
]]
local function reactive<T>(initialValue: T & {}): (T, (update: (T) -> () | T?) -> ())
	local track = signal(nil)
	local proxyApi = { value = initialValue, track = track }
	local proxyMap = setmetatable({} :: { [{}]: any }, { __mode = "v" })

	local function trackProperty(cache: { [any]: () -> any }, target: {}, key: any)
		if cache[key] then
			return cache[key]()
		end
		cache[key] = computed(function()
			track()
			return target[key]
		end)
		return cache[key]()
	end

	local function createProxy<T>(target: T & {}): ReactiveProxy<T>
		if proxyMap[target] then
			return proxyMap[target]
		end
		proxyMap[target] = setmetatable({
			__target = target,
			__signals = setmetatable({}, { __mode = "v" }),
		}, proxyApi)
		return proxyMap[target]
	end

	function proxyApi.__index(self: ReactiveProxy, key: any): any
		if activeSub then
			trackProperty(self.__signals, self.__target, key)
		end
		local value = self.__target[key]
		return if type(value) == "table" then createProxy(value) else value
	end

	function proxyApi.__newindex(self: ReactiveProxy, key: any, value: any)
		if type(value) == "table" and type(value.__target) == "table" then
			value = value.__target
		end
		if self.__target[key] ~= value then
			self.__target[key] = value
			trigger(track)
		end
	end

	function proxyApi.__iter(self: ReactiveProxy)
		track()
		return next, self.__target
	end

	function proxyApi.__len(self: ReactiveProxy)
		track()
		return #self.__target
	end

	function proxyApi.set(update: ((T) -> ()) | T?)
		if type(update) == "function" then
			update(initialValue)
		elseif type(update) == "table" then
			table.clear(initialValue)
			for key, value in update :: {} do
				(initialValue :: {})[key] = value
			end
		end
		trigger(track)
	end

	return createProxy(initialValue), proxyApi.set
end

--[[
	Unwraps a reactive proxy to get the original table. If the provided value
	is not a proxy, it is returned as-is.

	@param value A reactive proxy or a non-proxy value.
	@return The unwrapped target value.
	@see https://github.com/littensy/charm?tab=readme-ov-file#reactiveinitialvalue
]]
local function toRaw<T>(value: T): T
	if type(value) == "table" and type(value.__target) == "table" then
		-- Iteration starts tracking the reactive proxy
		for _ in value do
			break
		end
		return value.__target
	end
	return value
end

local reactiveSystem = system.createReactiveSystem({
	update = update,
	notify = notify,
	unwatched = unwatched,
})

link = reactiveSystem.link
unlink = reactiveSystem.unlink
propagate = reactiveSystem.propagate
checkDirty = reactiveSystem.checkDirty
shallowPropagate = reactiveSystem.shallowPropagate

return {
	ReactiveFlags = system.ReactiveFlags,
	flags = flags,
	getActiveSub = getActiveSub,
	setActiveSub = setActiveSub,
	startBatch = startBatch,
	endBatch = endBatch,
	signal = signal,
	computed = computed,
	effect = effect,
	effectScope = effectScope,
	trigger = trigger,
	atom = atom,
	onCleanup = onCleanup,
	untracked = untracked,
	peek = peek,
	batch = batch,
	subscribe = subscribe,
	listen = listen,
	recursive = recursive,
	observe = observe,
	mapped = mapped :: (<KI, VI, KO, VO>(
		getter: () -> { [KI]: VI },
		mapper: (item: VI, key: KI) -> (VO, KO)
	) -> () -> { [KO]: VO }) & (<K, VI, VO>(getter: () -> { [K]: VI }, mapper: (item: VI, key: K) -> VO) -> () -> { [K]: VO }),
	reactive = reactive,
	toRaw = toRaw,
}
