local batched = require("@self/batched")
local core = require("@self/core")
local flags = require("@self/flags")
local listen = require("@self/listen")
local mapped = require("@self/mapped")
local observe = require("@self/observe")
local subscribe = require("@self/subscribe")
local types = require("@self/types")
local untracked = require("@self/untracked")

export type Atom<T = any> = types.Atom<T>
export type Selector<T = any> = types.Selector<T>

--- @deprecated Function `batch()` is deprecated, use `batched()` instead.
local batch = batched
--- @deprecated Function `peek()` is deprecated, use `untracked()` instead.
local peek = untracked

return {
	core = core,
	flags = flags,
	atom = core.atom,
	computed = core.computed,
	effect = core.effect,
	effectScope = core.effectScope,
	onCleanup = core.onCleanup,
	batched = batched,
	listen = listen,
	mapped = mapped,
	observe = observe,
	subscribe = subscribe,
	untracked = untracked,
	-- Temporary aliases for backwards compatibility
	batch = batch,
	peek = peek,
}
