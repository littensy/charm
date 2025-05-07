local profiles: { [string]: number } = {}
local times: { [string]: number } = {}
local stack: { string } = {}

local function run(name: string, test: () -> ())
	local start = os.clock()
	local iter = 0

	table.clear(profiles)
	table.clear(times)
	table.clear(stack)

	while os.clock() - start < 2 do
		iter += 1
		test()
	end

	local elapsed = os.clock() - start
	local results = {}

	table.insert(results, `{name}: \t{string.format("%.2f", elapsed / iter * 1000 * 1000)} us/iter`)

	for name, elapsed in times do
		table.insert(results, `{name}: \t{string.format("%.2f", elapsed / iter * 1000 * 1000)} us/iter`)
	end

	print(table.concat(results, " | "))
end

local function profilebegin(name: string)
	profiles[name] = os.clock()
	table.insert(stack, name)
end

local function profileend()
	local name = table.remove(stack)

	if name then
		times[name] = (times[name] or 0) + os.clock() - profiles[name]
		profiles[name] = nil
	end
end

return {
	run = run,
	profilebegin = profilebegin,
	profileend = profileend,
}
