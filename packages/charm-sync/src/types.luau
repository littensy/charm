--[[
	A payload that can be sent from the server to the client to synchronize
	the states of the client's atoms with the server.
]]
export type SyncPayload =
	| {
		type: "init",
		data: { [string]: any },
	}
	| {
		type: "patch",
		data: { [string]: any },
	}

--[[
	A special type that represents a removed value in a patch. This is used to
	differentiate between a value that was set to `nil` and an unchanged value.
]]
export type None = { __none: "__none" }

export type ReactiveProxy<T = any> = typeof(setmetatable(
	{} :: {
		__track: () -> (),
		__target: T,
		__signals: { [unknown]: () -> unknown },
	},
	{} :: { __index: T }
))

return {}
