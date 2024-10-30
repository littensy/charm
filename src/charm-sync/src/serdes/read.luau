--!native
--!optimize 2

local kind = require(script.Parent.kind)
local stream = require(script.Parent.stream)

local read

local readers: { () -> unknown } = {
	[kind.reference] = stream.readref,

	[kind.int8] = stream.readi8,
	[kind.int16] = stream.readi16,
	[kind.int32] = stream.readi32,

	[kind.uint8] = stream.readu8,
	[kind.uint16] = stream.readu16,
	[kind.uint32] = stream.readu32,

	[kind.float32] = stream.readf32,
	[kind.float64] = stream.readf64,

	[kind.null] = function()
		return
	end,

	[kind.truthy] = function()
		return true
	end,

	[kind.falsy] = function()
		return false
	end,

	[kind.table] = function()
		local result = {}

		while stream.peeki8() ~= kind.terminate do
			local key = read()

			-- Skip invalid references
			if key == nil then
				continue
			end

			result[key] = read()
		end

		return result
	end,

	[kind.array] = function()
		local index = 1
		local result = {}

		while stream.peeki8() ~= kind.terminate do
			result[index] = read()
			index += 1
		end

		return result
	end,

	[kind.string] = function()
		local length = stream.readi16()
		return stream.readstring(length)
	end,

	[kind.vector] = function()
		return Vector3.new(stream.readf64(), stream.readf64(), stream.readf64())
	end,

	[kind.vector2] = function()
		return Vector2.new(stream.readf64(), stream.readf64())
	end,

	[kind.cframe] = function()
		local x, y, z = stream.readf64(), stream.readf64(), stream.readf64()
		local rx, ry, rz = stream.readf32(), stream.readf32(), stream.readf32()

		return CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz)
	end,

	[kind.color3] = function()
		return Color3.fromRGB(stream.readu8(), stream.readu8(), stream.readu8())
	end,
}

function read()
	local kind = stream.readi8()
	local reader = readers[kind]

	if not reader then
		error(`Failed to deserialize charm state: unknown value type {kind}`)
	end

	return reader()
end

return read
