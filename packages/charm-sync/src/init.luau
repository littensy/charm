local client = require(script.client)
local flatten = require(script.flatten)
local patch = require(script.patch)
local server = require(script.server)
local types = require(script.types)

export type SyncPayload = types.SyncPayload

--[=[
	Synchronizes state between the client and server. The server sends patches
	to the client, which applies them to its local state.
]=]
return {
	client = client,
	server = server,
	flatten = flatten,
	isNone = patch.isNone,
}
