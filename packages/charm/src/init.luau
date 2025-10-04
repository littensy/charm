local core = require("@self/core")
local flags = require("@self/flags")
local listen = require("@self/listen")
local mapped = require("@self/mapped")
local observe = require("@self/observe")
local subscribe = require("@self/subscribe")
local types = require("@self/types")
local utils = require("@self/utils")

--- A reactive atom that acts as both a getter and setter. Calling the atom with
--- an argument sets its value, while calling it with no arguments returns its
--- current value.
export type Atom<T = any> = types.Atom<T>

export type Selector<T = any> = types.Selector<T>

return {
	core = core,
	flags = flags,
	atom = core.atom,
	batched = core.batched,
	computed = core.computed,
	effect = core.effect,
	effectScope = core.effectScope,
	onCleanup = core.onCleanup,
	peek = core.peek,
	untracked = core.untracked,
	listen = listen,
	mapped = mapped,
	observe = observe,
	subscribe = subscribe,
	deepFreeze = utils.deepFreeze,
}
