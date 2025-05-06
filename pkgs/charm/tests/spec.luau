local suite = require("@tests/suite")

local describe = suite.describe

local function collect(name: string)
	describe(name, function()
		return require(`./{name}/spec`) :: any
	end)
end

local function spec(name: string)
	describe(name, function()
		return require(`./{name}.spec`) :: any
	end)
end

collect("signals")
spec("gc")
spec("listen")
spec("mapped")
spec("observe")
spec("subscribe")

return {}
