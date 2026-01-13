local fs = require("@std/fs")
local net = require("@lute/net")
local process = require("@lute/process")

process.run({ "rojo", "sourcemap", "--output=sourcemap.json" }, { stdio = "inherit" })

fs.writestringtofile(
	"roblox.d.luau",
	net.request("https://luau-lsp.pages.dev/globalTypes.None.d.luau", { method = "GET" }).body
)

local analyze = process.run({
	"luau-lsp",
	"analyze",
	"--sourcemap=sourcemap.json",
	"--ignore=**/node_modules/**",
	"--base-luaurc=.luaurc",
	"--definitions=roblox.d.luau",
	"packages",
	"tests",
	"benches",
}, { stdio = "inherit" })

fs.remove("roblox.d.luau")

local selene = process.run({ "selene", "packages", "tests", "benches" }, { stdio = "inherit" })

local stylua = process.run({ "stylua", "--check", "packages", "tests", "benches" }, { stdio = "inherit" })

local eslint = process.run({ "pnpm", "eslint", "packages" }, { stdio = "inherit" })

if not (analyze.ok and selene.ok and stylua.ok and eslint.ok) then
	process.exit(1)
end
