local fs = require("@std/fs")
local process = require("@lute/process")

fs.createDirectory("build")

process.run({ "rojo", "build", "--output=build/charm.rbxm", "build.project.json" }, { stdio = "inherit" })
