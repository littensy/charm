local function inlineTest(): string
	return debug.info(1, "n")
end

local isO2 = inlineTest() ~= "inlineTest"

return {
	--- Enforces synchronous, non-yielding behavior in atoms and effects.
	--- Enabled if the optimize level is below 2, which is the case in studio.
	strict = not isO2,
	--- Enforces immutability of atoms by deep-freezing table values. Disabled
	--- by default, but can be enabled to detect accidental mutations.
	frozen = false,
}
