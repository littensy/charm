--[=[
	A payload that can be sent from the server to the client to synchronize
	state between the two.
]=]
export type SyncPayload = {
	type: "init",
	data: { [string | number]: any },
} | {
	type: "patch",
	data: { [string | number]: any },
}

return nil
