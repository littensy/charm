--!native
--!optimize 2

local stream: buffer
local cursor: number
local length: number

local references: { unknown }
local referencesToIds: { [unknown]: number }
local referenceId: number

local function get()
	return stream, references
end

local function set(data: buffer, refs: { unknown })
	stream = data
	cursor = 0
	length = buffer.len(data)

	references = refs
	referencesToIds = {}
	referenceId = 0
end

local function create()
	length = 128
	stream = buffer.create(length)
	cursor = 0

	references = {}
	referencesToIds = {}
	referenceId = 0
end

local function allocate(bytes: number)
	if cursor + bytes < length then
		return
	end

	repeat
		length *= 2
	until cursor + bytes < length

	local target = buffer.create(length)

	buffer.copy(target, 0, stream)
	stream = target
end

local function writei8(value: number)
	allocate(1)
	buffer.writei8(stream, cursor, value)
	cursor += 1
end

local function peeki8()
	return buffer.readi8(stream, cursor)
end

local function readi8()
	local value = buffer.readi8(stream, cursor)
	cursor += 1
	return value
end

local function writei16(value: number)
	allocate(2)
	buffer.writei16(stream, cursor, value)
	cursor += 2
end

local function readi16()
	local value = buffer.readi16(stream, cursor)
	cursor += 2
	return value
end

local function writei32(value: number)
	allocate(4)
	buffer.writei32(stream, cursor, value)
	cursor += 4
end

local function readi32()
	local value = buffer.readi32(stream, cursor)
	cursor += 4
	return value
end

local function writeu8(value: number)
	allocate(1)
	buffer.writeu8(stream, cursor, value)
	cursor += 1
end

local function readu8()
	local value = buffer.readu8(stream, cursor)
	cursor += 1
	return value
end

local function writeu16(value: number)
	allocate(2)
	buffer.writeu16(stream, cursor, value)
	cursor += 2
end

local function readu16()
	local value = buffer.readu16(stream, cursor)
	cursor += 2
	return value
end

local function writeu32(value: number)
	allocate(4)
	buffer.writeu32(stream, cursor, value)
	cursor += 4
end

local function readu32()
	local value = buffer.readu32(stream, cursor)
	cursor += 4
	return value
end

local function writef32(value: number)
	allocate(4)
	buffer.writef32(stream, cursor, value)
	cursor += 4
end

local function readf32()
	local value = buffer.readf32(stream, cursor)
	cursor += 4
	return value
end

local function writef64(value: number)
	allocate(8)
	buffer.writef64(stream, cursor, value)
	cursor += 8
end

local function readf64()
	local value = buffer.readf64(stream, cursor)
	cursor += 8
	return value
end

local function writestring(value: string, length: number)
	allocate(length)
	buffer.writestring(stream, cursor, value)
	cursor += length
end

local function readstring(length: number)
	local value = buffer.readstring(stream, cursor, length)
	cursor += length
	return value
end

local function writeref(value: unknown)
	local id = referencesToIds[value]

	if not id then
		referenceId += 1
		references[referenceId] = value
		referencesToIds[value] = referenceId
		id = referenceId
	end

	allocate(2)
	buffer.writeu16(stream, cursor, id)
	cursor += 2
end

local function readref()
	local id = buffer.readu16(stream, cursor)
	cursor += 2
	return references[id]
end

return {
	get = get,
	set = set,
	create = create,

	writei8 = writei8,
	writei16 = writei16,
	writei32 = writei32,
	writeu8 = writeu8,
	writeu16 = writeu16,
	writeu32 = writeu32,
	writef32 = writef32,
	writef64 = writef64,
	writestring = writestring,
	writeref = writeref,

	peeki8 = peeki8,
	readi8 = readi8,
	readi16 = readi16,
	readi32 = readi32,
	readu8 = readu8,
	readu16 = readu16,
	readu32 = readu32,
	readf32 = readf32,
	readf64 = readf64,
	readstring = readstring,
	readref = readref,
}
