local store = require(script.Parent.store)

local function batch(callback: () -> ())
	if store.isBatching() then
		return callback()
	end

	local visited: { [() -> ()]: true } = {}

	store.setBatching(true)
	callback()
	store.setBatching(false)

	for atom in store.batched do
		for listener in pairs(store.listeners[atom]) do
			if not visited[listener] then
				visited[listener] = true
				listener()
			end
		end
	end

	table.clear(store.batched)
end

return batch
