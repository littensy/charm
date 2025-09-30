local client = require("@self/client")
local config = require("@self/config")
local flatten = require("@self/flatten")
local patch = require("@self/patch")
local server = require("@self/server")
local types = require("@self/types")

export type None = types.None
export type SyncPayload = types.SyncPayload

return {
	config = config,
	client = client,
	server = server,
	patch = patch,
	isNone = patch.isNone,
	flatten = flatten,
}
