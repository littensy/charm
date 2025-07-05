-- Adapted from Alien Signals
-- https://github.com/stackblitz/alien-signals
-- https://github.com/Nicell/alien-signals-luau

local config = require("./flags")
local system = require("./system")
local utils = require("./utils")

export type ReactiveFlags = system.ReactiveFlags
export type ReactiveNode = system.ReactiveNode
export type Link = system.Link

local ReactiveFlags = system.ReactiveFlags
local createReactiveSystem = system.createReactiveSystem
local deepFreeze = utils.deepFreeze
local noYield = utils.noYield

local NONE = 0b0000000
local MUTABLE = 0b0000001
local WATCHING = 0b0000010
local DIRTY = 0b0010000
local PENDING = 0b0100000
local QUEUED = 0b1000000

type EffectScope = ReactiveNode & {
	cleanups: { () -> () },
}

type Effect = ReactiveNode & {
	fn: () -> ...(() -> ())?,
	cleanups: { () -> () },
}

type Computed<T = any> = ReactiveNode & {
	value: T?,
	getter: (previousValue: T?) -> T,
	equals: ((T, T) -> boolean)?,
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
local queuedEffects: { Effect | EffectScope? } = {}
local queuedEffectsLength = 0
local notifyIndex = 0
local activeSubTracking = true
local activeSub: ReactiveNode?
local activeScope: Effect | EffectScope?

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

local function setCurrentTracking(tracking: boolean): boolean
	local prevSubTracking = activeSubTracking
	activeSubTracking = tracking
	return prevSubTracking
end

local function runCleanups(effect: EffectScope)
	for _, cleanup in effect.cleanups do
		local prev = setCurrentSub(nil)
		local success, result: unknown = (if config.strict then noYield else pcall)(cleanup)
		setCurrentSub(prev)
		if not success then
			error(result)
		end
	end
	table.clear(effect.cleanups)
end

local function onCleanup(cleanup: () -> (), failSilently: boolean?)
	if activeSub then
		table.insert((activeSub :: Effect).cleanups, cleanup)
	elseif activeScope then
		table.insert(activeScope.cleanups, cleanup)
	elseif not failSilently then
		warn(debug.traceback("onCleanup() can only be called inside an effect or a scope.", 2))
	end
end

local function run(effect: Effect | EffectScope, flags: ReactiveFlags): ()
	if bit32.btest(flags, DIRTY) or (bit32.btest(flags, PENDING) and checkDirty(effect.deps :: Link, effect)) then
		runCleanups(effect)
		local prev = setCurrentSub(effect)
		local prevTracking = setCurrentTracking(true)
		startTracking(effect)
		local success, result: (() -> ())? = (if config.strict then noYield else pcall)((effect :: Effect).fn)
		setCurrentSub(prev)
		endTracking(effect)
		setCurrentTracking(prevTracking)
		if not success then
			error(result)
		elseif result then
			table.insert(effect.cleanups, result)
		end
		return
	elseif bit32.btest(flags, PENDING) then
		(effect :: Effect).flags = bit32.band(flags, bit32.bnot(PENDING))
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
		local effect = queuedEffects[notifyIndex] :: Effect
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
	local prevTracking = setCurrentTracking(true)
	startTracking(computed)
	local oldValue = computed.value
	local success, result = (if config.strict then noYield else pcall)(computed.getter, oldValue)
	setCurrentSub(prevSub)
	endTracking(computed)
	setCurrentTracking(prevTracking)
	if not success then
		error(result)
	end
	local equals = computed.equals
	if if equals then not equals(oldValue, result) else oldValue ~= result then
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
	if activeSub and activeSubTracking then
		link(atom, activeSub)
	end
	return value
end

local function writeAtom<T>(atom: Atom<T>, oldValue: T, newValue: T): T
	local equals = atom.equals
	if if equals then not equals(oldValue, newValue :: T) else oldValue ~= newValue then
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
		if activeSub then
			if activeSubTracking then
				link(computed, activeSub)
			end
		elseif activeScope then
			link(computed, activeScope)
		end
		return computed.value :: T
	end
end

local function effectStop(self: Effect | EffectScope): () -> ()
	return function()
		local dep = self.deps
		while dep do
			dep = unlink(dep, self)
		end
		local sub = self.subs
		if sub then
			unlink(sub)
		end
		(self :: Effect).flags = NONE
		runCleanups(self)
	end
end

local function update(atom: Atom | Computed): boolean
	if (atom :: Computed).getter then
		return updateComputed(atom :: Computed)
	else
		return updateAtom(atom :: Atom, atom.value)
	end
end

local function notify(effect: Effect | EffectScope)
	local flags = effect.flags
	if not bit32.btest(flags, QUEUED) then
		(effect :: Effect).flags = bit32.bor(flags, QUEUED)
		local subs = effect.subs
		if subs then
			notify(subs.sub :: Effect)
		else
			queuedEffectsLength += 1
			queuedEffects[queuedEffectsLength] = effect
		end
	end
end

local function unwatched(node: Atom | Computed | Effect | EffectScope)
	if (node :: Computed).getter then
		local toRemove = node.deps
		if toRemove then
			(node :: Computed).flags = bit32.bor(MUTABLE, DIRTY)
			repeat
				toRemove = unlink(toRemove, node)
			until not toRemove
		end
	elseif (node :: Effect).cleanups then
		effectStop(node :: Effect)()
	end
end

local function atom<T>(initialValue: T, equals: ((T, T) -> boolean)?): (...((T) -> T) | T) -> T
	if config.frozen then
		deepFreeze(initialValue)
	end
	return atomGetterSetter({
		previousValue = initialValue,
		value = initialValue,
		flags = MUTABLE,
		equals = equals,
	})
end

local function computed<T>(getter: (previousValue: T?) -> T, equals: ((T, T) -> boolean)?): () -> T
	return computedGetter({
		flags = bit32.bor(MUTABLE, DIRTY),
		getter = getter,
		equals = equals,
	})
end

local function effect(fn: () -> ...(() -> ())?): () -> ()
	local self: Effect = {
		fn = fn,
		flags = WATCHING,
		cleanups = {},
	}
	if activeSub then
		link(self, activeSub)
	elseif activeScope then
		link(self, activeScope)
	end
	local prev = setCurrentSub(self)
	local prevTracking = setCurrentTracking(true)
	local success, result: (() -> ())? = (if config.strict then noYield else pcall)(fn)
	setCurrentSub(prev)
	setCurrentTracking(prevTracking)
	if not success then
		error(result)
	elseif result then
		table.insert(self.cleanups, result)
	end
	return effectStop(self)
end

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

local reactiveSystem = createReactiveSystem({
	update = update :: (ReactiveNode) -> boolean,
	notify = notify :: (ReactiveNode) -> (),
	unwatched = unwatched :: (ReactiveNode) -> (),
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
	setCurrentTracking = setCurrentTracking,
	onCleanup = onCleanup,
	getBatchDepth = getBatchDepth,
	startBatch = startBatch,
	endBatch = endBatch,
	atom = atom,
	computed = computed,
	effect = effect,
	effectScope = effectScope,
}
