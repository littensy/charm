local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net")
local process = require("@lute/process")

local CURRENT_FFLAGS = "https://clientsettingscdn.roblox.com/v1/settings/application?applicationName=PCStudioApp"
local FFLAG_KINDS = { "FFlag", "FInt" }

local function analyze()
	local args = {
		"luau-lsp",
		"analyze",
		"--sourcemap=sourcemap.json",
		"--ignore=**/node_modules/**",
		"--base-luaurc=.luaurc",
		"--definitions=roblox.d.luau",
		"--no-flags-enabled",
	}

	local response = net.request(CURRENT_FFLAGS, { method = "GET" })
	local data: any = json.deserialize(response.body)

	for name, value in data.applicationSettings do
		for _, kind in FFLAG_KINDS do
			if string.find(name, `^{kind}Luau`) then
				table.insert(args, `--flag:{string.sub(name, #kind + 1)}={value}`)
			end
		end
	end

	table.insert(args, "packages")
	table.insert(args, "tests")
	table.insert(args, "benches")

	local result = process.run(args)
	local stderr = string.gsub(result.stderr, "Unknown FFlag[^\n]+\n", "")

	print(stderr)

	if result.exitcode == 1 then
		process.exit(1)
	end
end

process.run({ "rojo", "sourcemap", "--output=sourcemap.json" }, { stdio = "inherit" })

fs.writestringtofile(
	"roblox.d.luau",
	net.request("https://luau-lsp.pages.dev/globalTypes.None.d.luau", { method = "GET" }).body
)

analyze()

-- process.run({
-- 	"luau-lsp",
-- 	"analyze",
-- 	"--sourcemap=sourcemap.json",
-- 	"--ignore=**/node_modules/**",
-- 	"--base-luaurc=.luaurc",
-- 	"--defs=roblox.d.luau",
-- 	"packages",
-- 	"tests",
-- 	"benches",
-- }, { stdio = "inherit" })

fs.remove("roblox.d.luau")

process.run({ "selene", "packages", "tests", "benches" }, { stdio = "inherit" })

process.run({ "stylua", "--check", "packages", "tests", "benches" }, { stdio = "inherit" })

process.run({ "pnpm", "eslint", "packages" }, { stdio = "inherit" })
