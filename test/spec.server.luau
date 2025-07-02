local Charm = require("../packages/charm/src")
local suite = require("./suite")

Charm.strict.enabled = true

require("../packages/charm/src/__tests__/spec")
require("../packages/charm-sync/src/__tests__/spec")
require("../packages/react-charm/src/__tests__/spec")
require("../packages/vide-charm/src/__tests__/spec")

suite.finish()
