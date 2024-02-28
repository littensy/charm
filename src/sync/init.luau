local client = require(script.client)
local server = require(script.server)
local types = require(script.types)

export type SyncPayload = types.SyncPayload

return {
	client = client,
	server = server,
}
