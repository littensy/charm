local store = require(script.Parent.store)

type Cleanup = () -> ()

--[=[
	Runs the given callback immediately and whenever any atom it depends on
	changes. Returns a cleanup function that unsubscribes the callback.
	
	@param callback The function to run.
	@return A function that unsubscribes the callback.
]=]
local function effect(callback: (cleanup: Cleanup) -> Cleanup?): Cleanup
	local dependencies = {}
	local cleanup: Cleanup?
	local disconnected = false
	local disconnect

	local function listener()
		if cleanup then
			cleanup()
		end

		store.disconnect(dependencies, listener)
		dependencies, cleanup = store.capture(callback, disconnect)

		if not disconnected then
			store.connect(dependencies, listener)
		end
	end

	function disconnect()
		if disconnected then
			return
		end

		disconnected = true
		store.disconnect(dependencies, listener)

		if cleanup then
			cleanup()
		end
	end

	dependencies, cleanup = store.capture(callback, disconnect)

	if not disconnected then
		store.connect(dependencies, listener)
	end

	return disconnect
end

return effect :: (callback: ((cleanup: Cleanup) -> ()) | ((cleanup: Cleanup) -> Cleanup?)) -> Cleanup
