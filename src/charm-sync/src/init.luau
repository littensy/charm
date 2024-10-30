local client = require(script.client)
local patch = require(script.patch)
local serdes = require(script.serdes)
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
	serialize = serdes.serialize,
	deserialize = serdes.deserialize,
	isNone = patch.isNone,
}
