local client = require(script.client)
local packets = require(script.packets)
local server = require(script.server)
local types = require(script.types)

export type SyncPayload = types.SyncPayload
export type Packet = packets.Packet

--[=[
	Synchronizes state between the client and server. The server sends patches
	to the client, which applies them to its local state.
]=]
return {
	client = client,
	server = server,
}
