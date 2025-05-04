--[=[
	alien-signals 2.0.1 implementation with effect cleanups, adopted from
	https://github.com/Nicell/alien-signals-luau
	https://github.com/stackblitz/alien-signals

	MIT License

	Copyright (c) 2024-present Johnson Chu, Nicholas Winans

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
]=]

local system = require("./system")

export type ReactiveFlags = system.ReactiveFlags
export type ReactiveNode = system.ReactiveNode
export type Link = system.Link

local ReactiveFlags = system.ReactiveFlags
local createReactiveSystem = system.createReactiveSystem

local NONE = 0b0000000
local MUTABLE = 0b0000001
local WATCHING = 0b0000010
local DIRTY = 0b0010000
local PENDING = 0b0100000
local QUEUED = 0b1000000

type EffectScope = ReactiveNode & {
	cleanup: (() -> ())?,
}

type Effect = ReactiveNode & {
	fn: () -> (() -> ())?,
	cleanup: (() -> ())?,
}

type Computed<T = any> = ReactiveNode & {
	value: T?,
	getter: (previousValue: T?) -> T,
}

type Signal<T = any> = ReactiveNode & {
	previousValue: T,
	value: T,
}

local pauseStack: { ReactiveNode? } = {}
local pauseStackCount = 0
local queuedEffects: { Effect | EffectScope } = {}

local link: (dep: ReactiveNode, sub: ReactiveNode) -> ()
local unlink: (link: Link, sub: ReactiveNode?) -> Link?
local propagate: (link: Link) -> ()
local checkDirty: (link: Link, sub: ReactiveNode) -> boolean
local endTracking: (sub: ReactiveNode) -> ()
local startTracking: (sub: ReactiveNode) -> ()
local shallowPropagate: (link: Link) -> ()

local batchDepth = 0

local notifyIndex = 0
local queuedEffectsLength = 0
local activeSub: ReactiveNode?
local activeScope: EffectScope?

local function getCurrentSub(): ReactiveNode?
	return activeSub
end

local function setCurrentSub(sub: ReactiveNode?)
	local prevSub = activeSub
	activeSub = sub
	return prevSub
end

local function getCurrentScope(): EffectScope?
	return activeScope
end

local function setCurrentScope(scope: EffectScope?)
	local prevScope = activeScope
	activeScope = scope
	return prevScope
end

local function pauseTracking()
	pauseStackCount += 1
	pauseStack[pauseStackCount] = activeSub
	activeSub = nil
end

local function resumeTracking()
	activeSub = pauseStack[pauseStackCount]
	pauseStack[pauseStackCount] = nil
	pauseStackCount -= 1
end

local function cleanup(e: ReactiveNode)
	local e = e :: EffectScope
	local cleanup = e.cleanup
	if cleanup then
		e.cleanup = nil
		local prev = setCurrentSub(nil)
		local success, result: unknown = pcall(cleanup)
		setCurrentSub(prev)
		if not success then
			error(result)
		end
	end
end

local function run(e: EffectScope, flags: ReactiveFlags): ()
	if bit32.band(flags, DIRTY) ~= 0 or (bit32.band(flags, PENDING) ~= 0 and checkDirty(e.deps :: Link, e)) then
		cleanup(e)
		local prev = setCurrentSub(e)
		startTracking(e)
		local success, result = pcall((e :: Effect).fn)
		setCurrentSub(prev)
		endTracking(e)
		if not success then
			error(result)
		end
		e.cleanup = result
		return
	elseif bit32.band(flags, PENDING) ~= 0 then
		e.flags = bit32.band(flags, bit32.bnot(PENDING))
	end
	local link = e.deps
	while link do
		local dep = link.dep
		local depFlags = dep.flags
		if bit32.band(depFlags, QUEUED) ~= 0 then
			depFlags = bit32.band(depFlags, bit32.bnot(QUEUED))
			dep.flags = depFlags
			run(dep :: EffectScope, depFlags)
		end
		link = link.nextDep
	end
end

local function flush(): ()
	while notifyIndex < queuedEffectsLength do
		notifyIndex += 1
		local effect = queuedEffects[notifyIndex] :: EffectScope
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

local function updateComputed(c: Computed): boolean
	local prevSub = setCurrentSub(c)
	startTracking(c)
	local oldValue = c.value
	local success, result = pcall(c.getter, oldValue)
	setCurrentSub(prevSub)
	endTracking(c)
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

local function updateSignal(s: Signal, value: any): boolean
	s.flags = MUTABLE
	if s.previousValue ~= value then
		s.previousValue = value
		return true
	else
		return false
	end
end

local function signalOper<T>(this: Signal<T>, ...: T): T?
	if select("#", ...) > 0 then
		local newValue = (...)
		if this.value ~= newValue then
			this.value = newValue
			this.flags = bit32.bor(MUTABLE, DIRTY)
			local subs = this.subs
			if subs then
				propagate(subs)
				if batchDepth == 0 then
					flush()
				end
			end
		end
		return
	else
		local value = this.value
		if bit32.band(this.flags, DIRTY) ~= 0 then
			if updateSignal(this, value) then
				local subs = this.subs
				if subs then
					shallowPropagate(subs)
				end
			end
		end
		if activeSub then
			link(this, activeSub)
		end
		return value
	end
end

local function computedOper<T>(this: Computed<T>): T
	local flags = this.flags
	if bit32.band(flags, DIRTY) ~= 0 or (bit32.band(flags, PENDING) ~= 0 and checkDirty(this.deps :: Link, this)) then
		if updateComputed(this) then
			local subs = this.subs
			if subs then
				shallowPropagate(subs)
			end
		end
	elseif bit32.band(flags, PENDING) ~= 0 then
		this.flags = bit32.band(flags, bit32.bnot(PENDING))
	end
	if activeSub then
		link(this, activeSub)
	elseif activeScope then
		link(this, activeScope)
	end
	return this.value :: T
end

local function effectOper(this: EffectScope): ()
	local dep = this.deps
	while dep do
		dep = unlink(dep, this)
	end
	local sub = this.subs
	while sub do
		unlink(sub)
		sub = this.subs
	end
	this.flags = NONE
	cleanup(this)
end

local signalMetatable = { __call = signalOper }
local computedMetatable = { __call = computedOper }
local effectMetatable = { __call = effectOper }

local function signal<T>(initialValue: T): ((T) -> ()) & (() -> T)
	local this: Signal<T> = {
		previousValue = initialValue,
		value = initialValue,
		flags = MUTABLE,
	}
	return setmetatable(this, signalMetatable) :: any
end

local function computed<T>(getter: (previousValue: T?) -> T): () -> T
	local this: Computed<T> = {
		flags = bit32.bor(MUTABLE, DIRTY),
		getter = getter,
	}
	return setmetatable(this, computedMetatable) :: any
end

local function effect(fn: () -> ...() -> ()?): () -> ()
	local e: Effect = {
		fn = fn,
		flags = WATCHING,
	}
	if activeSub then
		link(e, activeSub)
	elseif activeScope then
		link(e, activeScope)
	end
	local prev = setCurrentSub(e)
	local success, result = pcall(fn)
	setCurrentSub(prev)
	if not success then
		error(result)
	end
	e.cleanup = result
	return setmetatable(e, effectMetatable) :: any
end

local function effectScope(fn: () -> ...() -> ()?): () -> ()
	local e: EffectScope = {
		flags = NONE,
	}
	if activeScope then
		link(e, activeScope)
	end
	local prev = setCurrentSub(e)
	local success, result = pcall(fn)
	setCurrentSub(prev)
	if not success then
		error(result)
	end
	e.cleanup = result
	return setmetatable(e, effectMetatable) :: any
end

local function notify(e: ReactiveNode)
	local flags = e.flags
	if bit32.band(flags, QUEUED) == 0 then
		e.flags = bit32.bor(flags, QUEUED)
		local subs = e.subs
		if subs then
			notify(subs.sub :: Effect | EffectScope)
		else
			queuedEffectsLength += 1
			queuedEffects[queuedEffectsLength] = e :: Effect | EffectScope
		end
	end
end

local function update(signal: ReactiveNode): boolean
	if (signal :: Computed).getter then
		return updateComputed(signal :: Computed)
	else
		return updateSignal(signal :: Signal, (signal :: Signal).value)
	end
end

local function unwatched(signal: ReactiveNode)
	local toRemove = signal.deps
	if toRemove then
		repeat
			toRemove = unlink(toRemove, signal)
		until not toRemove
		signal.flags = bit32.bor(signal.flags, DIRTY)
	end
	cleanup(signal)
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
	getBatchDepth = getBatchDepth,
	startBatch = startBatch,
	endBatch = endBatch,
	pauseTracking = pauseTracking,
	resumeTracking = resumeTracking,
	signal = signal,
	computed = computed,
	effect = effect,
	effectScope = effectScope,
}
