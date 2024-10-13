--[=[
	A payload that can be sent from the server to the client to synchronize
	state between the two.
]=]
export type SyncPayload = {
	type: "patch" | "init",
	data: { [any]: any },
}

return nil
