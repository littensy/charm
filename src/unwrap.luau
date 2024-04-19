local store = require(script.Parent.store)

local function unwrap<T, U...>(callback: ((U...) -> T) | T, ...: U...): T
	if type(callback) ~= "function" then
		return callback
	end

	if not store.isCapturing() then
		return callback(...)
	end

	store.setCapturing(false)
	local result = callback(...)
	store.setCapturing(true)

	return result
end

return unwrap
