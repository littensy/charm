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

local NONE = 0b00000000
local MUTABLE = 0b00000001
local WATCHING = 0b00000010
local RECURSED_CHECK = 0b00000100
local RECURSED = 0b00001000
local DIRTY = 0b00010000
local PENDING = 0b00100000
local PEEKING = 0b10000000

local ReactiveFlags = {
	None = NONE,
	Mutable = MUTABLE,
	Watching = WATCHING,
	RecursedCheck = RECURSED_CHECK,
	Recursed = RECURSED,
	Dirty = DIRTY,
	Pending = PENDING,
}

local function createReactiveSystem(props: {
	update: (sub: ReactiveNode) -> boolean,
	notify: (sub: ReactiveNode) -> (),
	unwatched: (sub: ReactiveNode) -> (),
})
	local update = props.update
	local notify = props.notify
	local unwatched = props.unwatched

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

	local function link(dep: ReactiveNode, sub: ReactiveNode, version: number): ()
		-- DEVIATION: Do not link signals to sub while peeking
		if bit32.btest(sub.flags, PEEKING) and bit32.btest(dep.flags, MUTABLE) then
			return
		end
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

	local function propagate(link: Link): ()
		local next = link.nextSub
		local stack: Stack<Link?>?

		repeat
			local sub = link.sub

			local flags = sub.flags

			if not bit32.btest(flags, bit32.bor(RECURSED_CHECK, RECURSED, DIRTY, PENDING)) then
				sub.flags = bit32.bor(flags, PENDING)
			elseif not bit32.btest(flags, bit32.bor(RECURSED_CHECK, RECURSED)) then
				flags = NONE
			elseif not bit32.btest(flags, RECURSED_CHECK) then
				sub.flags = bit32.bor(bit32.band(flags, bit32.bnot(RECURSED)), PENDING)
			elseif not bit32.btest(flags, bit32.bor(DIRTY, PENDING)) and isValidLink(link, sub) then
				sub.flags = bit32.bor(flags, bit32.bor(RECURSED, PENDING))
				flags = bit32.band(flags, MUTABLE)
			else
				-- selene: allow(if_same_then_else)
				flags = NONE
			end

			if bit32.btest(flags, WATCHING) then
				notify(sub)
			end

			if bit32.btest(flags, MUTABLE) then
				local subSubs = sub.subs
				if subSubs then
					link = subSubs
					local nextSub = link.nextSub
					if nextSub then
						stack = { value = next, prev = stack }
						next = nextSub
					end
					continue
				end
			end

			link = next :: Link

			if link then
				next = link.nextSub
				continue
			end

			local continueTop = false

			while stack do
				link = stack.value :: Link
				stack = stack.prev
				if link then
					next = link.nextSub
					continueTop = true
					break
				end
			end

			if continueTop then
				continue
			end

			break
		until false
	end

	local function shallowPropagate(link: Link): ()
		repeat
			local sub = link.sub
			local flags = sub.flags
			if bit32.band(flags, bit32.bor(PENDING, DIRTY)) == PENDING then
				sub.flags = bit32.bor(flags, DIRTY)
				if bit32.btest(flags, WATCHING) then
					notify(sub)
				end
			end
			link = link.nextSub :: Link
		until not link
	end

	local function checkDirty(link: Link, sub: ReactiveNode): boolean
		local stack: Stack<Link>?
		local checkDepth = 0
		local dirty = false

		repeat
			local dep = link.dep
			local flags = dep.flags

			if bit32.btest(sub.flags, DIRTY) then
				dirty = true
			elseif bit32.band(flags, bit32.bor(MUTABLE, DIRTY)) == bit32.bor(MUTABLE, DIRTY) then
				if update(dep) then
					local subs = dep.subs :: Link
					if subs.nextSub then
						shallowPropagate(subs)
					end
					dirty = true
				end
			elseif bit32.band(flags, bit32.bor(MUTABLE, PENDING)) == bit32.bor(MUTABLE, PENDING) then
				if link.nextSub or link.prevSub then
					stack = { value = link, prev = stack }
				end
				link = dep.deps :: Link
				sub = dep
				checkDepth += 1
				continue
			end

			if not dirty then
				local nextDep = link.nextDep
				if nextDep then
					link = nextDep
					continue
				end
			end

			local continueTop = false

			while checkDepth ~= 0 do
				checkDepth -= 1
				local firstSub = sub.subs :: Link
				local hasMultipleSubs = firstSub.nextSub ~= nil
				if hasMultipleSubs then
					link = (stack :: Stack<Link>).value
					stack = (stack :: Stack<Link>).prev
				else
					link = firstSub
				end
				if dirty then
					if update(sub) then
						if hasMultipleSubs then
							shallowPropagate(firstSub)
						end
						sub = link.sub
						continue
					end
					dirty = false
				else
					sub.flags = bit32.band(sub.flags, bit32.bnot(PENDING))
				end
				sub = link.sub
				local nextDep = link.nextDep
				if nextDep then
					link = nextDep
					continueTop = true
					break
				end
			end

			if continueTop then
				continue
			end

			return dirty
		until false
	end

	return {
		link = link,
		unlink = unlink,
		propagate = propagate,
		checkDirty = checkDirty,
		shallowPropagate = shallowPropagate,
	}
end

return {
	ReactiveFlags = ReactiveFlags,
	createReactiveSystem = createReactiveSystem,
}
