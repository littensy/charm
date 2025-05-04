local listen = require("./listen")

local function observe<K, V>(selector: () -> { [K]: V }, observer: (item: V, key: K) -> ...() -> ()?): () -> ()
	local cleanups: { [K]: () -> ()? } = {}

	local unsub = listen(selector, function(currentItems, previousItems)
		if not previousItems then
			for key, value in currentItems do
				cleanups[key] = observer(value, key)
			end
			return
		end

		for key in previousItems do
			local cleanup = cleanups[key]
			if currentItems[key] == nil and cleanup then
				cleanups[key] = nil
				cleanup()
			end
		end

		for key, value in currentItems do
			if previousItems[key] == nil then
				cleanups[key] = observer(value, key)
			end
		end
	end)

	return function()
		unsub()
		for _, cleanup in cleanups do
			(cleanup :: () -> ())()
		end
		table.clear(cleanups)
	end
end

return observe
