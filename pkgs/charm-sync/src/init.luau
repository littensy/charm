local client = require(script.client)
local flatten = require(script.flatten)
local patch = require(script.patch)
local server = require(script.server)
local types = require(script.types)
local validate = require(script.validate)

export type SyncPayload = types.SyncPayload

return {
	client = client,
	server = server,
	flatten = flatten,
	validate = validate,
	patch = patch,
	isNone = patch.isNone,
}
