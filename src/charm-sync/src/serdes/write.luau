--!native
--!optimize 2

local kind = require(script.Parent.kind)
local stream = require(script.Parent.stream)
local writei8 = stream.writei8
local writei16 = stream.writei16
local writei32 = stream.writei32
local writeu8 = stream.writeu8
local writeu16 = stream.writeu16
local writeu32 = stream.writeu32
local writef32 = stream.writef32
local writef64 = stream.writef64
local writestring = stream.writestring
local writeref = stream.writeref

local write

local writers = {
	["nil"] = function()
		writei8(kind.null)
	end,

	reference = function(value: any)
		writei8(kind.reference)
		writeref(value)
	end,

	table = function(value: { [any]: any })
		local numeric = type((next(value))) == "number"
		local length = numeric and #value or 0
		local array = numeric and table.maxn(value) == length

		if array then
			writei8(kind.array)

			for index = 1, length do
				write(value[index])
			end

			writei8(kind.terminate)
		else
			writei8(kind.table)

			for key, value in next, value do
				write(key)
				write(value)
			end

			writei8(kind.terminate)
		end
	end,

	string = function(value: string)
		local length = #value

		writei8(kind.string)
		writei16(length)
		writestring(value, length)
	end,

	number = function(value: number)
		local integer = value % 1 == 0
		local unsigned = value >= 0

		if integer and unsigned then
			if value <= 2 ^ 8 - 1 then
				writei8(kind.uint8)
				writeu8(value)
			elseif value <= 2 ^ 16 - 1 then
				writei8(kind.uint16)
				writeu16(value)
			elseif value <= 2 ^ 32 - 1 then
				writei8(kind.uint32)
				writeu32(value)
			else
				writei8(kind.float64)
				writef64(value)
			end
		elseif integer then
			if value >= -2 ^ 7 and value <= 2 ^ 7 - 1 then
				writei8(kind.int8)
				writei8(value)
			elseif value >= -2 ^ 15 and value <= 2 ^ 15 - 1 then
				writei8(kind.int16)
				writei16(value)
			elseif value >= -2 ^ 31 and value <= 2 ^ 31 - 1 then
				writei8(kind.int32)
				writei32(value)
			else
				writei8(kind.float64)
				writef64(value)
			end
		else
			writei8(kind.float64)
			writef64(value)
		end
	end,

	boolean = function(value: boolean)
		writei8(value and kind.truthy or kind.falsy)
	end,

	buffer = function(value: buffer)
		local length = buffer.len(value)

		writei8(kind.string)
		writei16(length)
		writestring(buffer.tostring(value), length)
	end,

	vector = function(value: Vector3)
		writei8(kind.vector)
		writef64(value.X)
		writef64(value.Y)
		writef64(value.Z)
	end,

	Vector2 = function(value: Vector2)
		writei8(kind.vector2)
		writef64(value.X)
		writef64(value.Y)
	end,

	CFrame = function(value: CFrame)
		local x, y, z = value.X, value.Y, value.Z
		local rx, ry, rz = value:ToEulerAngles()

		writei8(kind.cframe)
		writef64(x)
		writef64(y)
		writef64(z)
		writef32(rx)
		writef32(ry)
		writef32(rz)
	end,

	Color3 = function(value: Color3)
		writei8(kind.color3)
		writei8(value.R * 255)
		writei8(value.G * 255)
		writei8(value.B * 255)
	end,
}

function write(value: any)
	local primitive = type(value)
	local kind = primitive == "userdata" and typeof(value) or primitive
	local writer = writers[kind] or writers.reference

	writer(value)
end

return write
