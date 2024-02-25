local function isAtom(value: any)
	return type(value) == "table" and getmetatable(value) and getmetatable(value).__type == "Atom" or false
end

return isAtom
