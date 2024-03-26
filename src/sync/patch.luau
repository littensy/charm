local validate = require(script.Parent.validate)

local NONE = { __none = "__none" }

local warnings = {}

local function diff(prevState: { [any]: any }, nextState: { [any]: any })
	local patches = table.clone(nextState)

	for key, previous in prevState do
		local next = nextState[key]

		if previous == next then
			patches[key] = nil
		elseif next == nil then
			patches[key] = NONE
		elseif type(previous) == "table" and type(next) == "table" then
			patches[key] = diff(previous, next)
		end
	end

	if _G.__DEV__ then
		local success, result = pcall(function()
			for key, value in prevState do
				validate(value, key)
			end
			for key, value in nextState do
				if prevState[key] ~= value then
					validate(value, key)
				end
			end
		end)

		if not success and not warnings[result] then
			warnings[result] = true
			warn(result)
		end
	end

	return patches
end

local function apply(state: { [any]: any }, patches: { [any]: any })
	local nextState = table.clone(state)

	for key, patch in patches do
		local current = nextState[key]

		if type(patch) == "table" and patch.__none == "__none" then
			nextState[key] = nil
		elseif type(patch) == "table" and type(current) == "table" then
			nextState[key] = apply(current, patch)
		else
			nextState[key] = patch
		end
	end

	return nextState
end

return {
	diff = diff,
	apply = apply,
}
