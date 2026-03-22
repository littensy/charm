--[[
	Reactive system adapted from alien-signals at
	https://github.com/stackblitz/alien-signals/blob/master/src/system.ts
]]

export type ReactiveNode = {
	deps: Link?,
	depsTail: Link?,
	subs: Link?,
	subsTail: Link?,
	flags: ReactiveFlags,
}

export type Link = {
	version: number,
	dep: ReactiveNode,
	sub: ReactiveNode,
	prevSub: Link?,
	nextSub: Link?,
	prevDep: Link?,
	nextDep: Link?,
}

type Stack<T> = {
	value: T,
	prev: Stack<T>?,
}

export type ReactiveFlags = number

local NONE = 0b000000
local MUTABLE = 0b000001
local WATCHING = 0b000010
local RECURSED_CHECK = 0b000100
local RECURSED = 0b001000
local DIRTY = 0b010000
local PENDING = 0b100000

local ReactiveFlags = table.freeze({
	None = NONE,
	Mutable = MUTABLE,
	Watching = WATCHING,
	RecursedCheck = RECURSED_CHECK,
	Recursed = RECURSED,
	Dirty = DIRTY,
	Pending = PENDING,
})

local update: (sub: ReactiveNode) -> boolean
local notify: (sub: ReactiveNode) -> ()
local unwatched: (sub: ReactiveNode) -> ()

local function isValidLink(checkLink: Link, sub: ReactiveNode): boolean
	local link = sub.depsTail
	while link do
		if link == checkLink then
			return true
		end
		link = link.prevDep
	end
	return false
end

local function link(dep: ReactiveNode, sub: ReactiveNode, version: number)
	local prevDep = sub.depsTail
	if prevDep and prevDep.dep == dep then
		return
	end
	local nextDep = if prevDep then prevDep.nextDep else sub.deps
	if nextDep and nextDep.dep == dep then
		nextDep.version = version
		sub.depsTail = nextDep
		return
	end
	local prevSub = dep.subsTail
	if prevSub and prevSub.version == version and prevSub.sub == sub then
		return
	end
	local newLink: Link = {
		version = version,
		dep = dep,
		sub = sub,
		prevDep = prevDep,
		nextDep = nextDep,
		prevSub = prevSub,
	}
	sub.depsTail = newLink
	dep.subsTail = newLink
	if nextDep then
		nextDep.prevDep = newLink
	end
	if prevDep then
		prevDep.nextDep = newLink
	else
		sub.deps = newLink
	end
	if prevSub then
		prevSub.nextSub = newLink
	else
		dep.subs = newLink
	end
end

local function unlink(link: Link, sub: ReactiveNode?): Link?
	local sub = sub or link.sub
	local dep = link.dep
	local prevDep = link.prevDep
	local nextDep = link.nextDep
	local nextSub = link.nextSub
	local prevSub = link.prevSub
	if nextDep then
		nextDep.prevDep = prevDep
	else
		sub.depsTail = prevDep
	end
	if prevDep then
		prevDep.nextDep = nextDep
	else
		sub.deps = nextDep
	end
	if nextSub then
		nextSub.prevSub = prevSub
	else
		dep.subsTail = prevSub
	end
	if prevSub then
		prevSub.nextSub = nextSub
	else
		dep.subs = nextSub
		if not nextSub then
			unwatched(dep)
		end
	end
	return nextDep
end

local function propagate(link: Link)
	repeat
		local sub = link.sub
		local flags = sub.flags

		if bit32.band(flags, bit32.bor(RECURSED_CHECK, RECURSED, DIRTY, PENDING)) == 0 then
			sub.flags = bit32.bor(flags, PENDING)
		elseif bit32.band(flags, bit32.bor(RECURSED_CHECK, RECURSED)) == 0 then
			flags = NONE
		elseif bit32.band(flags, RECURSED_CHECK) == 0 then
			sub.flags = bit32.bor(bit32.band(flags, bit32.bnot(RECURSED)), PENDING)
		elseif bit32.band(flags, bit32.bor(DIRTY, PENDING)) == 0 and isValidLink(link, sub) then
			sub.flags = bit32.bor(flags, bit32.bor(RECURSED, PENDING))
			flags = bit32.band(flags, MUTABLE)
		else
			-- selene: allow(if_same_then_else)
			flags = NONE
		end

		if bit32.band(flags, bit32.bor(WATCHING, RECURSED_CHECK)) == WATCHING then
			notify(sub)
		end

		if bit32.btest(flags, MUTABLE) then
			local subSubs = sub.subs
			if subSubs then
				propagate(subSubs)
			end
		end

		link = link.nextSub :: Link
	until not link
end

local function shallowPropagate(link: Link)
	repeat
		local sub = link.sub
		local flags = sub.flags
		if bit32.band(flags, bit32.bor(PENDING, DIRTY)) == PENDING then
			sub.flags = bit32.bor(flags, DIRTY)
			if bit32.band(flags, bit32.bor(WATCHING, RECURSED_CHECK)) == WATCHING then
				notify(sub)
			end
		end
		link = link.nextSub :: Link
	until not link
end

local function checkDirty(link: Link, sub: ReactiveNode): boolean
	repeat
		local dep = link.dep
		local depFlags = dep.flags

		if bit32.btest(sub.flags, DIRTY) then
			return true
		elseif bit32.band(depFlags, bit32.bor(MUTABLE, DIRTY)) == bit32.bor(MUTABLE, DIRTY) then
			if update(dep) then
				local subs = dep.subs :: Link
				if subs.nextSub then
					shallowPropagate(subs)
				end
				return true
			end
		elseif bit32.band(depFlags, bit32.bor(MUTABLE, PENDING)) == bit32.bor(MUTABLE, PENDING) then
			if checkDirty(dep.deps :: Link, dep) then
				if update(dep) then
					local subs = dep.subs :: Link
					if subs.nextSub then
						shallowPropagate(subs)
					end
					return true
				end
			else
				dep.flags = bit32.band(depFlags, bit32.bnot(PENDING))
			end
		end

		link = link.nextDep :: Link
	until not link

	return false
end

local function createReactiveSystem(
	updateFn: (sub: ReactiveNode) -> boolean,
	notifyFn: (sub: ReactiveNode) -> (),
	unwatchedFn: (sub: ReactiveNode) -> ()
)
	update = updateFn
	notify = notifyFn
	unwatched = unwatchedFn
end

return {
	ReactiveFlags = ReactiveFlags,
	link = link,
	unlink = unlink,
	propagate = propagate,
	checkDirty = checkDirty,
	shallowPropagate = shallowPropagate,
	createReactiveSystem = createReactiveSystem,
}
