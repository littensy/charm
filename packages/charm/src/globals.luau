local function inlineTest(): string
	return debug.info(1, "n")
end

local isO2 = inlineTest() ~= "inlineTest"
local isDev = not isO2 or _G.__DEV__ == true

return {
	--- Enforces synchronous, non-yielding behavior in signals and effects.
	--- Also enables state validation in Charm Sync to catch sync errors early.
	--- Enabled if the optimization level is below 2, which is true in studio.
	strict = isDev,
	--- Enforces immutability of tables by deep-freezing table values. Enabled
	--- if the optimization level is below 2, which is true in studio.
	frozen = isDev,
	--- Whether parent effects should track inner effects and clean them up
	--- when the parent effect re-runs. This is usually desirable, but can be
	--- disabled to revert to the old behavior. Defaults to `true`.
	trackInnerEffects = true,
	--- Whether to allow recursive updates in effects and computed signals.
	--- Disabling this can help catch certain classes of bugs, but may also
	--- cause valid code to error. Defaults to `false`.
	allowRecursion = false,
}
