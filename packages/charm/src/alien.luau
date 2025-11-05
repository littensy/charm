local globals = require("./globals")
--[[
	Reactive system adapted from alien-signals at
	https://github.com/stackblitz/alien-signals/blob/master/src/system.ts

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

local NONE = 0b0000000
local MUTABLE = 0b0000001
local WATCHING = 0b0000010
local RECURSED_CHECK = 0b0000100
local RECURSED = 0b0001000
local DIRTY = 0b0010000
local PENDING = 0b0100000
local PEEKING = 0b1000000

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
		local allowRecursion = globals.allowRecursion

		repeat
			local sub = link.sub
			local flags = sub.flags

			if allowRecursion then
				flags = bit32.band(flags, bit32.bnot(bit32.bor(RECURSED, RECURSED_CHECK)))
				sub.flags = flags
			end

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
