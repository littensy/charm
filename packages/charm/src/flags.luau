local function inlineTest(): string
	return debug.info(1, "n")
end

local isO2 = inlineTest() ~= "inlineTest"

return {
	--- Enforces synchronous, non-yielding behavior in atoms and effects.
	--- Also enables state validation in Charm Sync to catch sync errors early.
	--- Enabled if the optimization level is below 2, which is true in studio.
	strict = not isO2,
	--- Enforces immutability of atoms by deep-freezing table values. Enabled
	--- if the optimization level is below 2, which is true in studio.
	frozen = not isO2,
}
