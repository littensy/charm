local store = require(script.Parent.store)

local function unwrap<T>(atom: (() -> T) | T): T
	if type(atom) ~= "function" then
		return atom
	end

	if not store.shouldCapture() then
		return atom()
	end

	store.setCapturing(false)
	local success, result = pcall(atom)
	store.setCapturing(true)

	if not success then
		error(`Failed to unwrap atom: ${result}`, 2)
	end

	return result
end

return unwrap
