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
		to `false` for performance reasons.
	]]
	preserveHistory = false,
	--[[
		When `true`, Charm will modify sparse arrays to prevent data loss from
		remote event limitations. When an unsafe array is detected, numeric
		indices will be converted to string keys so that the array can be sent
		safely and then converted back to an array on the receiving end.

		This option should be disabled if your network library uses a custom
		serialization method (i.e. Zap, ByteNet) to prevent interference.
	]]
	fixArrays = true,
	--[[
		When `true`, synced state containing unsafe sparse arrays or mixed
		tables will emit a warning. Only checked in strict mode and if
		`fixArrays` is enabled. Defaults to `true`.
	]]
	validatePatches = true,
}
