local store = require(script.Parent.store)

type Cleanup = () -> ()

--[=[
	Runs the given callback immediately and whenever any atom it depends on
	changes. Returns a cleanup function that unsubscribes the callback.
	
	@param callback The function to run.
	@return A function that unsubscribes the callback.
]=]
local function effect(callback: () -> (() -> ())?): () -> ()
	local dependencies, cleanup = store.capture(callback)
	local disconnected = false

	local function listener()
		if cleanup then
			cleanup()
		end

		store.disconnect(dependencies, listener)
		dependencies, cleanup = store.capture(callback)

		if not disconnected then
			store.connect(dependencies, listener)
		end
	end

	store.connect(dependencies, listener)

	return function()
		if disconnected then
			return
		end

		disconnected = true
		store.disconnect(dependencies, listener)

		if cleanup then
			cleanup()
		end
	end
end

return effect :: (callback: (() -> ()) | (() -> Cleanup)) -> Cleanup
