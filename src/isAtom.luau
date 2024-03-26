local store = require(script.Parent.store)

local function isAtom(value: any)
	return value ~= nil and store.listeners[value] :: any ~= nil
end

return isAtom
