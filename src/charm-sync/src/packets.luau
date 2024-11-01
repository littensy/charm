export type Packet = {
	path: { string | number },
	data: any,
}

local packets: { Packet }
local counter: number

local function push(path: { string | number }, key: string | number)
	local result = table.clone(path)
	table.insert(result, key)
	return result
end

local function append(path: { string | number }, data: unknown)
	packets[counter] = { path = path, data = data }
	counter += 1
end

local function visit(
	previousState: { [string | number]: any },
	currentState: { [string | number]: any },
	path: { string | number }
)
	local empty = next(currentState) == nil

	if empty then
		-- Overwrite with an empty table instead of deleting keys
		return append(path, currentState)
	end

	-- Search keys for removals and changes, but not additions
	for key, previous in next, previousState do
		local current = currentState[key]

		if current == previous then
			continue
		elseif current == nil then
			append(push(path, key), nil)
		elseif type(current) == "table" and type(previous) == "table" then
			visit(previous, current, push(path, key))
		else
			append(push(path, key), current)
		end
	end

	-- Search for additions not present in the previous state
	for key, current in next, currentState do
		if previousState[key] == nil then
			append(push(path, key), current)
		end
	end
end

local function diff(previous: { [string | number]: any }, current: { [string | number]: any })
	packets = {}
	counter = 1
	visit(previous, current, {})
	return packets
end

local function apply(state: { [string | number]: any }, packets: { Packet })
	local result = table.clone(state)
	local copied = {}

	local function resolve(path: { string | number })
		local object = result
		local length = #path
		local id = ""

		for index = 1, length - 1 do
			local key = path[index]

			id ..= "\\" .. tostring(key)

			-- Prepare a deep copy of the object if it hasn't been accessed yet
			if not copied[id] then
				copied[id] = true
				object[key] = table.clone(object[key])
			end

			object = object[key]
		end

		return object, path[length]
	end

	for _, packet in next, packets do
		local object, key = resolve(packet.path)

		object[key] = packet.data
	end

	return result
end

return {
	diff = diff,
	apply = apply,
}
