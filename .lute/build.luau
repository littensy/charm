local fs = require("@std/fs")
local process = require("@lute/process")

fs.createdirectory("build")

process.run({ "rojo", "build", "--output=build/charm.rbxm" }, { stdio = "inherit" })
