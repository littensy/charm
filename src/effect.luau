local store = require(script.Parent.store)

type Cleanup = () -> ()

--[=[
	Runs the given callback immediately and whenever any atom it depends on
	changes. Returns a cleanup function that unsubscribes the callback.
	
	@param callback The function to run.
	@return A function that unsubscribes the callback.
]=]
local function effect(callback: () -> any): () -> ()
	local dependencies, cleanup = store.capture(callback)

	local function listener()
		if cleanup then
			cleanup()
		end

		dependencies, cleanup = store.reconnect(callback, dependencies, listener)
	end

	store.connect(dependencies, listener)

	return function()
		store.disconnect(dependencies, listener)

		if cleanup then
			cleanup()
		end
	end
end

return effect :: (callback: (() -> ()) | (() -> Cleanup)) -> Cleanup
