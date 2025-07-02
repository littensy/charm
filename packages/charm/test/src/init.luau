local batched = require("@self/batched")
local core = require("@self/core")
local listen = require("@self/listen")
local mapped = require("@self/mapped")
local observe = require("@self/observe")
local strict = require("@self/strict")
local subscribe = require("@self/subscribe")
local types = require("@self/types")
local untracked = require("@self/untracked")

export type Atom<T = any> = types.Atom<T>
export type Selector<T = any> = types.Selector<T>

local atom = core.atom
local computed = core.computed
local effect = core.effect
local effectScope = core.effectScope
local onCleanup = core.onCleanup

return {
	core = core,
	strict = strict,
	atom = atom,
	batched = batched,
	computed = computed,
	effect = effect,
	effectScope = effectScope,
	listen = listen,
	mapped = mapped,
	observe = observe,
	onCleanup = onCleanup,
	subscribe = subscribe,
	untracked = untracked,
}
