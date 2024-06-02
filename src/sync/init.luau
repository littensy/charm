local client = require(script.client)
local server = require(script.server)

--[=[
	Synchronizes state between the client and server. The server sends patches
	to the client, which applies them to its local state.
]=]
return {
	client = client,
	server = server,
}
