local fs = require("@std/fs")
local net = require("@lute/net")
local process = require("@lute/process")

process.run({ "rojo", "sourcemap", "--output=sourcemap.json" }, { stdio = "inherit" })

fs.writestringtofile(
	"roblox.d.luau",
	net.request("https://luau-lsp.pages.dev/globalTypes.None.d.luau", { method = "GET" }).body
)

process.run({
	"luau-lsp",
	"analyze",
	"--sourcemap=sourcemap.json",
	"--ignore=**/node_modules/**",
	"--base-luaurc=.luaurc",
	"--defs=roblox.d.luau",
	"packages",
	"tests",
	"benches",
}, { stdio = "inherit" })

fs.remove("roblox.d.luau")

process.run({ "selene", "packages", "tests", "benches" }, { stdio = "inherit" })

process.run({ "stylua", "--check", "packages", "tests", "benches" }, { stdio = "inherit" })

process.run({ "pnpm", "eslint", "packages" }, { stdio = "inherit" })
