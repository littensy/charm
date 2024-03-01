local validate = require(script.Parent.validate)

local NONE = { __none = "__none" }

local function diff(previousState: { [any]: any }, nextState: { [any]: any })
	local patch = table.clone(nextState)

	for key, previous in previousState do
		local next = nextState[key]

		if previous == next then
			patch[key] = nil
		elseif next == nil then
			patch[key] = NONE
		elseif type(previous) == "table" and type(next) == "table" then
			patch[key] = diff(previous, next)
		end
	end

	if _G.__DEV__ then
		local success, result = pcall(function()
			for key, value in previousState do
				validate(value, key)
			end
			for key, value in nextState do
				validate(value, key)
			end
		end)

		if not success then
			warn(result)
		end
	end

	return patch
end

local function apply(state: { [any]: any }, patchState: { [any]: any })
	local nextState = table.clone(state)

	for key, patch in patchState do
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
