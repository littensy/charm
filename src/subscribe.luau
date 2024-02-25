local atom = require(script.Parent.atom)
type Atom<T> = atom.Atom<T>

local reference = require(script.Parent.utils.reference)

local function subscribe<State>(atom: Atom<State>, callback: (state: State, previous: State) -> ()): (() -> (), () -> ())
	local pending: thread? = nil
	local state = atom:get()

	local function emit()
		local lastState = state
		state = atom:get()
		callback(state, lastState)
	end

	local function update()
		pending = pending or task.defer(function()
			pending = nil
			emit()
		end)
	end

	local function flush()
		if pending then
			pending = task.cancel(pending)
			emit()
		end
	end

	local function unsubscribe()
		reference.release(atom)
		atom.listeners[update] = nil

		if pending then
			pending = task.cancel(pending)
		end
	end

	-- Ensure the atom is held in memory while the subscription is active
	reference.hold(atom)
	atom.listeners[update] = true

	return unsubscribe, flush
end

return subscribe
