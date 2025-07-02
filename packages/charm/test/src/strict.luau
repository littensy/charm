local function inlineTest(): string
	return debug.info(1, "n")
end

return {
	-- Enable strict mode in O2
	enabled = inlineTest() == "inlineTest",
}
