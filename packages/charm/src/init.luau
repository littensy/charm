local core = require("@self/core")
local globals = require("@self/globals")
local mapped = require("@self/mapped")
local observe = require("@self/observe")
local utils = require("@self/utils")

type Update<T> = ((previous: T) -> T) | T

--- A reactive atom that acts as both a getter and setter. Calling the atom with
--- an argument sets its value, while calling it with no arguments returns its
--- current value.
export type Atom<T = any> = (...Update<T>) -> T

export type Selector<T = any> = () -> T

return {
	core = core,
	globals = globals,
	atom = core.atom,
	batched = core.batched,
	computed = core.computed,
	effect = core.effect,
	effectScope = core.effectScope,
	listen = core.listen,
	onCleanup = core.onCleanup,
	peek = core.peek,
	signal = core.signal,
	subscribe = core.subscribe,
	untracked = core.untracked,
	mapped = mapped,
	observe = observe,
	deepFreeze = utils.deepFreeze,
}
