local core = require("@self/core")
local globals = require("@self/globals")
local mapped = require("@self/mapped")
local observe = require("@self/observe")
local utils = require("@self/utils")

type Update<T> = ((previous: T) -> T) | T

--- A reactive signal that acts as both a getter and setter. Calling the signal
--- with an argument sets its value, while calling it with no arguments returns
--- its current value.
export type Atom<T = any> = (...Update<T>) -> T

--- A getter-only reactive signal. Calling the signal with no arguments returns
--- its current value. It cannot be set directly.
export type Getter<T = any> = () -> T

--- A setter-only reactive signal. Calling the signal with an argument sets its
--- value. It cannot be read directly.
export type Setter<T = any> = (...Update<T>) -> ()

export type ReactiveNode = core.ReactiveNode
export type Link = core.Link

return {
	core = core,
	globals = globals,
	atom = core.atom,
	batch = core.batch,
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
