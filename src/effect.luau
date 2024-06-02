local store = require(script.Parent.store)

type Cleanup = () -> ()

--[=[
	Runs the given callback immediately and whenever any atom it depends on
	changes. Returns a cleanup function that unsubscribes the callback.
	
	Note that dependencies are only evaluated once when the effect is created,
	and conditional dependencies may not work as expected.
	
	@param callback The function to run.
	@return A function that unsubscribes the callback.
]=]
local function effect(callback: () -> any): () -> ()
	local captured, cleanup = store.capture(callback)

	local function listener()
		if cleanup then
			cleanup()
		end

		cleanup = callback()
	end

	for atom in captured do
		store.listeners[atom][listener] = true
	end

	return function()
		for atom in captured do
			store.listeners[atom][listener] = nil
		end

		if cleanup then
			cleanup()
		end
	end
end

return effect :: (callback: (() -> ()) | (() -> Cleanup)) -> Cleanup
