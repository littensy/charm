local client = require("@self/client")
local flatten = require("@self/flatten")
local patch = require("@self/patch")
local server = require("@self/server")
local types = require("@self/types")
local validate = require("@self/validate")

export type SyncPayload = types.SyncPayload

return {
	client = client,
	server = server,
	flatten = flatten,
	validate = validate,
	patch = patch,
	isNone = patch.isNone,
}
