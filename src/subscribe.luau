local store = require(script.Parent.store)
local types = require(script.Parent.types)
type Molecule<T> = types.Molecule<T>

--[=[
	Subscribes to changes in the given atom or molecule. The callback is
	called with the current state and the previous state immediately after a
	change occurs.
	
	@param molecule The atom or molecule to subscribe to.
	@param callback The function to call when the state changes.
	@return A function that unsubscribes the callback.
]=]
local function subscribe<T>(molecule: Molecule<T>, callback: (state: T, prev: T) -> ()): () -> ()
	local dependencies, state = store.capture(molecule)
	local disconnected = false

	local function listener()
		local prevState = state

		store.disconnect(dependencies, listener)
		dependencies, state = store.capture(molecule)

		if not disconnected then
			store.connect(dependencies, listener)
		end

		if state ~= prevState then
			callback(state, prevState)
		end
	end

	store.connect(dependencies, listener)

	return function()
		if not disconnected then
			disconnected = true
			store.disconnect(dependencies, listener)
		end
	end
end

return subscribe
