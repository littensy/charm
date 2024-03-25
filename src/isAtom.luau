local store = require(script.Parent.store)

local function isAtom(value: any)
	return type(value) == "function" and store.listeners[value] :: any ~= nil
end

return isAtom
