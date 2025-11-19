return {
	--[[
		The interval at which to send patches to the client, in seconds.
		Defaults to `0` (patches are sent up to once per frame). Set to a
		negative value to disable automatic syncing.
	]]
	interval = 0,
	--[[
		Whether the history of state changes since the client's last update
		should be preserved. This is useful for values that change multiple
		times per frame, where each individual change is important. Defaults
		to `false`.
	]]
	preserveHistory = false,
	--[[
		When `true`, Charm will apply validation and serialize unsafe arrays
		to address remote event argument limitations. Defaults to `true`.
		This option should be disabled if your network library uses a custom
		serialization method (i.e. Zap, ByteNet) to prevent interference.
	]]
	fixArrays = true,
	--[[
		When `true`, synced state containing unsafe sparse arrays or mixed
		tables will throw an error. Only checked in strict mode and if
		`fixArrays` is enabled. Defaults to `true`.
	]]
	validatePatches = true,
}
