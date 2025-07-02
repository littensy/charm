local Charm = require("../../Charm")
local CharmSync = require("../")
local suite = require("../../../../test/suite")

type SyncPayload = CharmSync.SyncPayload

local atom = Charm.atom
local server = CharmSync.server
local patch = CharmSync.patch
local test = suite.test

local target: Player = {} :: any

test("sends state to new players", function()
	local a = atom(1)
	local server = server({ atoms = { a = a }, interval = -1 })
	local player: Player, payload: SyncPayload

	local disconnect = server:connect(function(...)
		player, payload = ...
	end)

	server:hydrate(target)

	assert(player == target, "should send to the target player")
	assert(payload.type == "init", "should be an init payload")
	assert(payload.data.a == 1, "should send the initial state")

	disconnect()
end)

test("sends state patches", function()
	local a = atom({ b = 1, c = 2 } :: { [string]: number? })
	local server = server({ atoms = { a = a }, interval = -1 })
	local player: Player, payload: SyncPayload

	local disconnect = server:connect(function(...)
		player, payload = ...
	end)

	a({ b = 1, c = 5 })
	server:_sendPatch(target)

	assert(player == target, "should send to the target player")
	assert(payload.type == "patch", "should be a patch payload")
	assert(payload.data.a.b == nil, "should not send unchanged values")
	assert(payload.data.a.c == 5, "should send changed values")

	a({ b = 1, d = 1 })
	server:_sendPatch(target)

	assert(payload.data.a.b == nil, "should not send unchanged values")
	assert(patch.isNone(payload.data.a.c) == true, "should send None for removed values")
	assert(payload.data.a.d == 1, "should send new values")

	disconnect()
end)

test("preserves history", function()
	local a = atom(1)
	local b = atom(1)
	local payloads: { SyncPayload }

	local server = server({
		atoms = { a = a, b = b },
		interval = -1,
		preserveHistory = true,
	})

	local disconnect = server:connect(function(_, ...)
		payloads = { ... }
	end)

	a(2)
	b(2)
	server:_sendPatch(target)

	assert(#payloads == 1, "should only have one payload")
	assert(payloads[1].type == "patch", "should be a patch payload")
	assert(payloads[1].data.a == 2, "should send the new value of a")
	assert(payloads[1].data.b == 2, "should send the new value of b")

	a(3)
	a(4)
	b(3)
	server:_sendPatch(target)

	assert(#payloads == 2, "should have two payloads")
	assert(payloads[1].type == "patch", "1 should be a patch payload")
	assert(payloads[1].data.a == 3, "1 should send the new value of a")
	assert(payloads[1].data.b == nil, "1 should not send unchanged values")
	assert(payloads[2].type == "patch", "2 should be a patch payload")
	assert(payloads[2].data.a == 4, "2 should send the new value of a")
	assert(payloads[2].data.b == 3, "2 should send the new value of b")

	disconnect()
end)

return {}
