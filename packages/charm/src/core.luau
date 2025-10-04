-- Adapted from Alien Signals
-- https://github.com/stackblitz/alien-signals
-- https://github.com/Nicell/alien-signals-luau

local alien = require("./alien")
local config = require("./flags")
local utils = require("./utils")

export type ReactiveFlags = alien.ReactiveFlags
export type ReactiveNode = alien.ReactiveNode
export type Link = alien.Link

local ReactiveFlags = alien.ReactiveFlags
local createReactiveSystem = alien.createReactiveSystem
local deepFreeze = utils.deepFreeze
local noYield = utils.noYield

local NONE = 0b0000000
local MUTABLE = 0b0000001
local WATCHING = 0b0000010
local DIRTY = 0b0010000
local PENDING = 0b0100000
local QUEUED = 0b1000000
local UNTRACKED = 0b10000000

type EffectScope = ReactiveNode & {
	cleanups: { () -> () },
}

type Effect = ReactiveNode & {
	fn: (dispose: () -> ()) -> ...(() -> ())?,
	cleanups: { () -> () },
	cleanup: () -> (),
}

type Computed<T = any> = ReactiveNode & {
	value: T?,
	getter: (previousValue: T?) -> T,
}

type Atom<T = any> = ReactiveNode & {
	previousValue: T,
	value: T,
	equals: ((T, T) -> boolean)?,
}

local link: (dep: ReactiveNode, sub: ReactiveNode) -> ()
local unlink: (link: Link, sub: ReactiveNode?) -> Link?
local propagate: (link: Link) -> ()
local checkDirty: (link: Link, sub: ReactiveNode) -> boolean
local endTracking: (sub: ReactiveNode) -> ()
local startTracking: (sub: ReactiveNode) -> ()
local shallowPropagate: (link: Link) -> ()

local batchDepth = 0

local queuedEffects: { Effect } = {}
local queuedEffectsLength = 0
local notifyIndex = 0

local activeScope: Effect | EffectScope?
local activeSub: ReactiveNode?

local function getCurrentSub(): ReactiveNode?
	return activeSub
end

local function setCurrentSub(sub: ReactiveNode?)
	local prevSub = activeSub
	activeSub = sub
	return prevSub
end

local function getCurrentScope(): Effect | EffectScope?
	return activeScope
end

local function setCurrentScope(scope: Effect | EffectScope?)
	local prevScope = activeScope
	activeScope = scope
	return prevScope
end

local function runCleanups(effect: EffectScope)
	for _, cleanup in effect.cleanups do
		local prev = setCurrentSub(nil)
		local success, result: any = (if config.strict then noYield else pcall)(cleanup)
		setCurrentSub(prev)
		if not success then
			error(result)
		end
	end
	table.clear(effect.cleanups)
end

local function run(effect: Effect, flags: ReactiveFlags): ()
	if bit32.btest(flags, DIRTY) or (bit32.btest(flags, PENDING) and checkDirty(effect.deps :: Link, effect)) then
		runCleanups(effect)
		local prev = setCurrentSub(effect)
		startTracking(effect)
		local success, result: (() -> ())? = (if config.strict then noYield else pcall)(effect.fn, effect.cleanup)
		setCurrentSub(prev)
		endTracking(effect)
		if not success then
			error(result)
		elseif result then
			table.insert(effect.cleanups, result)
		end
		return
	elseif bit32.btest(flags, PENDING) then
		effect.flags = bit32.band(flags, bit32.bnot(PENDING))
	end
	local link = effect.deps
	while link do
		local dep = link.dep
		local depFlags = dep.flags
		if bit32.btest(depFlags, QUEUED) then
			depFlags = bit32.band(depFlags, bit32.bnot(QUEUED))
			dep.flags = depFlags
			run(dep :: Effect, depFlags)
		end
		link = link.nextDep
	end
end

local function flush(): ()
	while notifyIndex < queuedEffectsLength do
		notifyIndex += 1
		local effect = queuedEffects[notifyIndex]
		queuedEffects[notifyIndex] = nil
		effect.flags = bit32.band(effect.flags, bit32.bnot(QUEUED))
		run(effect, effect.flags)
	end
	notifyIndex = 0
	queuedEffectsLength = 0
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

local function updateComputed(computed: Computed): boolean
	local prevSub = setCurrentSub(computed)
	startTracking(computed)
	local oldValue = computed.value
	local success, result = (if config.strict then noYield else pcall)(computed.getter, oldValue)
	setCurrentSub(prevSub)
	endTracking(computed)
	if not success then
		error(result)
	end
	if oldValue ~= result then
		computed.value = result
		return true
	else
		return false
	end
end

local function updateAtom(atom: Atom, value: any): boolean
	atom.flags = MUTABLE
	if atom.previousValue ~= value then
		atom.previousValue = value
		return true
	else
		return false
	end
end

local function readAtom<T>(atom: Atom<T>): T
	local value = atom.value
	if bit32.btest(atom.flags, DIRTY) then
		if updateAtom(atom, value) then
			local subs = atom.subs
			if subs then
				shallowPropagate(subs)
			end
		end
	end
	if activeSub and not bit32.btest(activeSub.flags, UNTRACKED) then
		link(atom, activeSub)
	end
	return value
end

local function writeAtom<T>(atom: Atom<T>, oldValue: T, newValue: T): T
	local equals = atom.equals
	if if equals then not equals(oldValue, newValue) else oldValue ~= newValue then
		if config.frozen then
			deepFreeze(newValue)
		end
		atom.value = newValue
		atom.flags = bit32.bor(MUTABLE, DIRTY)
		local subs = atom.subs
		if subs then
			propagate(subs)
			if batchDepth == 0 then
				flush()
			end
		end
		return newValue
	end
	return oldValue
end

local function atomGetterSetter<T>(atom: Atom<T>): (...((T) -> T) | T) -> T
	return function(...)
		if select("#", ...) == 0 then
			return readAtom(atom)
		end
		local oldValue = atom.value
		local newValue = ...
		if type(newValue) == "function" then
			local prev = setCurrentSub(nil)
			local success, result = (if config.strict then noYield else pcall)(newValue, oldValue)
			setCurrentSub(prev)
			if not success then
				error(result)
			end
			newValue = result
		end
		return writeAtom(atom, oldValue, newValue :: T)
	end
end

local function computedGetter<T>(computed: Computed<T>): () -> T
	return function()
		local flags = computed.flags
		if
			bit32.btest(flags, DIRTY) or (bit32.btest(flags, PENDING) and checkDirty(computed.deps :: Link, computed))
		then
			if updateComputed(computed) then
				local subs = computed.subs
				if subs then
					shallowPropagate(subs)
				end
			end
		elseif bit32.btest(flags, PENDING) then
			computed.flags = bit32.band(flags, bit32.bnot(PENDING))
		end
		if activeSub and not bit32.btest(activeSub.flags, UNTRACKED) then
			link(computed, activeSub)
		elseif activeScope then
			link(computed, activeScope)
		end
		return computed.value :: T
	end
end

local function effectStop(self: EffectScope): () -> ()
	return function()
		local dep = self.deps
		while dep do
			dep = unlink(dep, self)
		end
		local sub = self.subs
		if sub then
			unlink(sub)
		end
		self.flags = NONE
		runCleanups(self)
	end
end

local function update(atom: ReactiveNode): boolean
	if (atom :: Computed).getter then
		return updateComputed(atom :: Computed)
	else
		return updateAtom(atom :: Atom, (atom :: Atom).value)
	end
end

local function notify(effect: ReactiveNode)
	local flags = effect.flags
	if not bit32.btest(flags, QUEUED) then
		effect.flags = bit32.bor(flags, QUEUED)
		local subs = effect.subs
		if subs then
			notify(subs.sub :: Effect)
		else
			queuedEffectsLength += 1
			queuedEffects[queuedEffectsLength] = effect :: Effect
		end
	end
end

local function unwatched(node: ReactiveNode)
	if (node :: Computed).getter then
		local toRemove = node.deps
		if toRemove then
			node.flags = bit32.bor(MUTABLE, DIRTY)
			repeat
				toRemove = unlink(toRemove, node)
			until not toRemove
		end
	elseif (node :: Effect).cleanups then
		effectStop(node :: Effect)()
	end
end

--- Creates a reactive atom that acts as both a getter and setter. Calling the
--- atom with an argument sets its value, while calling it with no arguments
--- returns its current value.
---
--- @param value The initial value of the atom. If empty, the atom's value will be `undefined`.
--- @param equals A comparator function to determine if the atom's value has changed.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#atomstate-options
local function atom<T>(value: T, equals: ((T, T) -> boolean)?): (...((T) -> T) | T) -> T
	if config.frozen then
		deepFreeze(value)
	end
	return atomGetterSetter({
		previousValue = value,
		value = value,
		flags = MUTABLE,
		equals = equals,
	})
end

--- Creates a new atom that is computed based on the values of other atoms.
--- The returned atom is read-only, and its value is automatically updated when
--- any atoms accessed from within the getter function change.
---
--- If an initial value is provided, the getter will receive this value as its
--- first argument on the initial run, instead of `undefined`.
---
--- @example
--- ```ts
--- const count = atom(1);
--- const plusOne = computed(() => count() + 1);
--- print(plusOne()); // 2
--- ```
---
--- @param getter A function that produces the next value.
--- @param value An optional initial value for the selector.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#computedcallback-options
local function computed<T>(getter: (previousValue: T?) -> T, value: T?): () -> T
	return computedGetter({
		flags = bit32.bor(MUTABLE, DIRTY),
		getter = getter,
		value = value,
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
local function effect(fn: (dispose: () -> ()) -> ...(() -> ())?): () -> ()
	local self: Effect = {
		fn = fn,
		flags = WATCHING,
		cleanups = {},
		cleanup = nil :: any,
	}
	self.cleanup = effectStop(self)
	if activeSub and config.trackInnerEffects then
		link(self, activeSub)
	elseif activeScope then
		link(self, activeScope)
	end
	local prev = setCurrentSub(self)
	local success, result: (() -> ())? = (if config.strict then noYield else pcall)(fn, self.cleanup)
	setCurrentSub(prev)
	if not success then
		error(result)
	elseif result then
		table.insert(self.cleanups, result)
	end
	return self.cleanup
end

--- Creates an effect scope that can capture multiple reactive effects (i.e.
--- computed, effect, subscribe) created within it so that they can be disposed
--- together.
---
--- @param fn A function that may create reactive effects.
--- @param detached If true, the scope will not be automatically disposed of when the parent scope is disposed. Defaults to false.
--- @return A function for disposing all effects created within the scope.
--- @see https://github.com/littensy/charm?tab=readme-ov-file#effectscopecallback-detached
local function effectScope(fn: () -> ...(() -> ())?, detached: boolean?): () -> ()
	local self: EffectScope = {
		flags = NONE,
		cleanups = {},
	}
	if activeScope and not detached then
		link(self, activeScope)
	end
	local prevSub = setCurrentSub(nil)
	local prevScope = setCurrentScope(self)
	local success, result: (() -> ())? = (if config.strict then noYield else pcall)(fn)
	setCurrentScope(prevScope)
	setCurrentSub(prevSub)
	if not success then
		error(result)
	elseif result then
		table.insert(self.cleanups, result)
	end
	return effectStop(self)
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
	elseif activeScope then
		table.insert(activeScope.cleanups, cleanup)
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
local function untracked<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	local prevSub = setCurrentSub(nil)
	local prevScope = setCurrentScope(nil)
	local results: { any } = { pcall(callback, ...) }
	setCurrentSub(prevSub)
	setCurrentScope(prevScope)
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
local function peek<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	if not activeSub or bit32.btest(activeSub.flags, UNTRACKED) then
		return callback(...)
	else
		activeSub.flags = bit32.bor(activeSub.flags, UNTRACKED)
		local results: { any } = { pcall(callback, ...) }
		activeSub.flags = bit32.band(activeSub.flags, bit32.bnot(UNTRACKED))
		if not results[1] then
			error(results[2])
		end
		return unpack(results, 2)
	end
end

--- Combines multiple atom updates into a single "commit" that runs effects at
--- the end of the provided callback.
---
--- @param callback A function that performs multiple atom updates.
--- @param args Arguments to pass to the callback.
--- @return The return value of the callback.
local function batched<Args..., Results...>(callback: (Args...) -> Results..., ...: Args...): Results...
	startBatch()
	local results: { any } = { (if config.strict then noYield else pcall)(callback, ...) }
	endBatch()
	if not results[1] then
		error(results[2])
	end
	return unpack(results, 2)
end

local reactiveSystem = createReactiveSystem({
	update = update,
	notify = notify,
	unwatched = unwatched,
})

link = reactiveSystem.link
unlink = reactiveSystem.unlink
propagate = reactiveSystem.propagate
checkDirty = reactiveSystem.checkDirty
endTracking = reactiveSystem.endTracking
startTracking = reactiveSystem.startTracking
shallowPropagate = reactiveSystem.shallowPropagate

return {
	ReactiveFlags = ReactiveFlags,
	createReactiveSystem = createReactiveSystem,
	getCurrentSub = getCurrentSub,
	setCurrentSub = setCurrentSub,
	getCurrentScope = getCurrentScope,
	setCurrentScope = setCurrentScope,
	onCleanup = onCleanup,
	getBatchDepth = getBatchDepth,
	startBatch = startBatch,
	endBatch = endBatch,
	atom = atom,
	computed = computed,
	effect = effect,
	effectScope = effectScope,
	untracked = untracked,
	peek = peek,
	batched = batched,
}
