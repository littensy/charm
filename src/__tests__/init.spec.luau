local reference = require(script.Parent.Parent.utils.reference)

return function()
	afterEach(function()
		reference.clear()
	end)
end
