local validate = require(script.Parent.validate)

--[=[
	A special symbol that denotes the absence of a value. Used to represent
	deleted values in patches.
]=]
local None = { __none = "__none" }

local function isNone(value: any): boolean
	return type(value) == "table" and value.__none == "__none"
end

local function diff(prevState: { [any]: any }, nextState: { [any]: any })
	local patches = table.clone(nextState)

	for key, previous in next, prevState do
		local current = nextState[key]

		if previous == current then
			patches[key] = nil
		elseif current == nil then
			patches[key] = None
		elseif type(previous) == "table" and type(current) == "table" then
			patches[key] = diff(previous, current)
		end
	end

	if _G.__DEV__ then
		for key, value in next, prevState do
			validate(value, key, "state")
		end

		for key, value in nextState do
			if prevState[key] ~= value then
				validate(value, key, "state")
			end
		end
	end

	return patches
end

local function apply(state: any, patches: any): any
	if type(patches) == "table" and patches.__none == "__none" then
		return nil
	elseif type(state) ~= "table" or type(patches) ~= "table" then
		return patches
	end

	local nextState = table.clone(state)

	for key, patch in next, patches do
		nextState[key] = apply(nextState[key], patch)
	end

	return nextState
end

return {
	None = None,
	isNone = isNone,
	diff = diff,
	apply = apply,
}
