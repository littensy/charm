local test = require("../../../tests/test")

local tests = {
	"computed",
	"effect",
	"effectScope",
	"gc",
	"listen",
	"mapped",
	"observe",
	"peek",
	"reactive",
	"signal",
	"subscribe",
	"topology",
	"trigger",
	"untracked",
}

for _, name in tests do
	test.describe(name, function()
		(require)(`@self/{name}.test`)
	end)
end

return {}
