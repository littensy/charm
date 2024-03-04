local atom = require(script.Parent.atom)
type Atom<T> = atom.Atom<T>
local subscribe = require(script.Parent.subscribe)

local function observe<Item, Key>(atom: Atom<{ [Key]: Item }>, factory: (value: Item, key: Key) -> () -> ()): (() -> (), () -> ())
	local connections: { [Key]: () -> () } = {}

	local function update(state: { [Key]: Item })
		for key, disconnect in connections do
			if state[key] == nil then
				connections[key] = nil
				disconnect()
			end
		end

		for key, value in state do
			if not connections[key] then
				connections[key] = factory(value, key)
			end
		end
	end

	local unsubscribe, flush = subscribe(atom, update)

	local function cleanup()
		unsubscribe()
		for _, disconnect in connections do
			disconnect()
		end
	end

	update(atom:get())

	return cleanup, flush
end

return observe
