local atom = require("@self/atom")
local batched = require("@self/batched")
local effect = require("@self/effect")
local listen = require("@self/listen")
local mapped = require("@self/mapped")
local observe = require("@self/observe")
local onCleanup = require("@self/onCleanup")
local signals = require("@self/signals")
local subscribe = require("@self/subscribe")
local types = require("@self/types")
local untracked = require("@self/untracked")

export type Atom<T = any> = types.Atom<T>
export type Getter<T = any> = types.Getter<T>
export type Selector<T = any> = types.Selector<T>
export type Setter<T = any> = types.Setter<T>
export type Update<T = any> = types.Update<T>

local computed = signals.computed
local effectScope = signals.effectScope

return {
	atom = atom,
	batched = batched,
	computed = computed,
	effect = effect,
	effectScope = effectScope,
	listen = listen,
	mapped = mapped,
	observe = observe,
	subscribe = subscribe,
	untracked = untracked,
	onCleanup = onCleanup,
	signals = signals,
}
