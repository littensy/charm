local types = require(script.Parent.types)
local read = require(script.read)
local stream = require(script.stream)
local write = require(script.write)

local function serialize(data: types.SyncPayload)
	stream.create()
	write(data)
	return stream.get()
end

local function deserialize(data: buffer, references: { unknown })
	stream.set(data, references)
	return read()
end

return {
	serialize = serialize,
	deserialize = deserialize,
}
