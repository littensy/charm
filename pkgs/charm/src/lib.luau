local atom = require("./atom")
local batched = require("./batched")
local effect = require("./effect")
local listen = require("./listen")
local mapped = require("./mapped")
local observe = require("./observe")
local onCleanup = require("./onCleanup")
local signals = require("./signals")
local subscribe = require("./subscribe")
local types = require("./types")
local untracked = require("./untracked")

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
