local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Selector<T> = types.Selector<T>

--[=[
	Subscribes to changes in the given atom or selector. The callback is
	called with the current state and the previous state immediately after a
	change occurs.
	
	@param callback The atom or selector to subscribe to.
	@param listener The function to call when the state changes.
	@return A function that unsubscribes the callback.
]=]
local function subscribe<T>(callback: Selector<T>, listener: (state: T, prev: T) -> ()): () -> ()
	local dependencies, state = store.capture(callback)
	local disconnected = false

	local function handler()
		local prevState = state

		store.disconnect(dependencies, handler)
		dependencies, state = store.capture(callback)

		if not disconnected then
			store.connect(dependencies, handler)
		end

		if state ~= prevState then
			listener(state, prevState)
		end
	end

	store.connect(dependencies, handler)

	return function()
		if not disconnected then
			disconnected = true
			store.disconnect(dependencies, handler)
		end
	end
end

return subscribe
