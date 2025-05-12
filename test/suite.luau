type Config = {
	colors: boolean?,
	verbose: boolean?,
}

type Description = {
	status: number,
	name: string,
	only: boolean,
	skip: boolean,
	parent: Description?,
	children: { Description | Test },
	passes: number,
	fails: number,
	skips: number,
	runtime: number,
}

type Test = {
	status: number,
	name: string,
	only: boolean,
	skip: boolean,
	parent: Description?,
	children: nil,
	run: () -> (),
	result: unknown?,
	line: number?,
	runtime: number,
}

local options = {
	colors = true,
	verbose = false,
}

local color = {
	white = function(text: string)
		return if options.colors then `\27[37;1m{text}\27[0m` else text
	end,
	gray = function(text: string)
		return if options.colors then `\27[90;1m{text}\27[0m` else text
	end,
	green = function(text: string)
		return if options.colors then `\27[32;1m{text}\27[0m` else `\u{1F7E2} {text}`
	end,
	red = function(text: string)
		return if options.colors then `\27[31;1m{text}\27[0m` else `\u{1F534} {text}`
	end,
	blue = function(text: string)
		return if options.colors then `\27[34;1m{text}\27[0m` else `\u{1F535} {text}`
	end,
}

local PENDING = 0
local PASS = 1
local FAIL = 2
local SKIP = 3
local ERROR = 4

local tests: { Test } = {}
local descriptions: { Description } = {}
local root: Description = {
	status = PENDING,
	name = "root",
	only = false,
	skip = false,
	children = {},
	passes = 0,
	fails = 0,
	skips = 0,
	runtime = 0,
}
local parent: Description = root

local function describe(name: string, run: () -> ()): Description
	local this: Description = {
		status = PENDING,
		name = name,
		only = false,
		skip = false,
		parent = parent,
		children = {},
		passes = 0,
		fails = 0,
		skips = 0,
		runtime = 0,
	}

	local prevDescription = parent
	parent = this
	run()
	parent = prevDescription

	table.insert(parent.children, this)
	table.insert(descriptions, this)

	return this
end

local function test(name: string, run: () -> ()): Test
	local this: Test = {
		status = PENDING,
		name = name,
		only = false,
		skip = false,
		parent = parent,
		run = run,
		runtime = 0,
	}

	table.insert(parent.children, this)
	table.insert(tests, this)

	return this
end

local function skip()
	parent.skip = true
end

local function only()
	parent.only = true
	root.only = true
end

local function testSkip(name: string, run: () -> ()): Test
	local this = test(name, run)
	this.skip = true
	return this
end

local function testOnly(name: string, run: () -> ()): Test
	local this = test(name, run)
	this.only = true
	root.only = true
	return this
end

local function describeSkip(name: string, run: () -> ()): Description
	local this = describe(name, run)
	this.skip = true
	return this
end

local function describeOnly(name: string, run: () -> ()): Description
	local this = describe(name, run)
	this.only = true
	root.only = true
	return this
end

local function isOnly(test: Test): boolean
	if not root.only or test.only then
		return true
	end

	local description = test.parent
	while description and description ~= root do
		if description.only then
			return true
		elseif description.skip then
			return false
		end
		description = description.parent
	end

	return false
end

local function isSkip(test: Test): boolean
	if test.only then
		return false
	elseif test.skip then
		return true
	end

	local description = test.parent
	while description do
		if description.only and description ~= root then
			return false
		elseif description.skip then
			return true
		end
		description = description.parent
	end

	return false
end

local function runTests()
	for _, test in tests do
		if isSkip(test) or not isOnly(test) then
			test.status = SKIP
			continue
		end

		local start = os.clock()
		local success = xpcall(test.run, function(result)
			test.status = FAIL
			test.result = result
			test.line = debug.info(3, "l")
		end)

		test.runtime = os.clock() - start

		if success then
			test.status = PASS
		end
	end
end

local function updateDescription(description: Description)
	if not description.children[1] then
		description.status = PASS
		return
	end

	description.status = SKIP

	for _, child in description.children do
		if child.children then
			updateDescription(child)
			description.passes += child.passes
			description.fails += child.fails
		elseif child.status == PASS then
			description.passes += 1
		elseif child.status == FAIL then
			description.fails += 1
		end

		-- Only count skips in direct children
		if child.status == SKIP then
			description.skips += 1
		end

		description.runtime += child.runtime

		if child.status == FAIL then
			description.status = FAIL
		elseif description.status == SKIP and child.status == PASS then
			description.status = PASS
		end
	end
end

local function getIndent(node: Description | Test): string
	local depth = 0
	local description = node.parent
	while description and description ~= root do
		depth += 1
		description = description.parent
	end
	return if depth > 0 then string.rep("  ", depth - 1) .. color.gray("· ") else ""
end

local function getPath(node: Description | Test): string
	local path = { "" }
	local description = node.parent
	while description and description ~= root do
		table.insert(path, 1, description.name)
		description = description.parent
	end
	return table.concat(path, " > ")
end

local function greenOrRed(text: string, good: boolean): string
	return if good then color.green(text) else color.red(text)
end

local function colorStatus(status: number): string
	local wall = color.gray("│")

	if status == PASS then
		return color.green("PASS") .. wall
	elseif status == FAIL then
		return color.red("FAIL") .. wall
	elseif status == SKIP then
		return color.blue("SKIP") .. wall
	else
		return color.red("ERROR") .. wall
	end
end

local function report()
	local output = {}

	local function reportDescription(description: Description)
		local name = color.white(description.name)
		local text = `{colorStatus(description.status)} {getIndent(description)}{name}`

		if description.fails > 0 then
			text ..= " " .. color.red(`({description.fails})`)
		end

		if description.skips > 0 then
			text ..= " " .. color.blue(`({description.skips} skipped)`)
		elseif description.fails == 0 then
			text ..= " " .. color.gray(string.format("%.2fms", description.runtime * 1000))
		end

		table.insert(output, text)
	end

	local function reportTest(test: Test, reportError: boolean?)
		if test.status ~= FAIL and not options.verbose then
			return
		end

		local line = color.red(`{test.line}:`)

		if reportError then
			local name = color.white(test.name)
			local path = color.gray(getPath(test))

			table.insert(output, `{colorStatus(ERROR)} {path}{line}{name}`)
			table.insert(output, `{test.result}`)
		else
			local name = color.gray(test.name)
			local indent = getIndent(test)

			if test.status == FAIL then
				table.insert(output, `{colorStatus(FAIL)} {indent}{line}{name}`)
			else
				table.insert(output, `{colorStatus(test.status)} {indent}{name}`)
			end
		end
	end

	local function reportNode(node: Description | Test)
		if not node.children then
			return reportTest(node :: Test)
		end

		reportDescription(node)

		for _, child in node.children do
			reportNode(child)
		end
	end

	local function reportSummary()
		local describePasses = 0
		local describeFails = 0

		for _, description in descriptions do
			if description.status == PASS then
				describePasses += 1
			elseif description.status == FAIL then
				describeFails += 1
			end
		end

		local describes =
			`{greenOrRed(`{describePasses} passed`, describeFails == 0)} {color.gray(`({#descriptions})`)}`
		local tests = `{greenOrRed(`{root.passes} passed`, root.fails == 0)} {color.gray(`({#tests})`)}`
		local duration = `{color.blue(`{string.format("%.2fms", root.runtime * 1000)}`)}`

		table.insert(output, "")
		table.insert(output, `Describe  {describes}`)
		table.insert(output, `   Tests  {tests}`)
		table.insert(output, `Duration  {duration}`)
		table.insert(output, "")
	end

	local function reportErrors()
		if root.fails == 0 then
			return
		end

		for _, test in tests do
			if test.status == FAIL then
				reportTest(test, true)
				table.insert(output, "")
			end
		end
	end

	table.insert(output, "")
	table.insert(output, color.blue("Test Results"))
	table.insert(output, "")

	for _, child in root.children do
		reportNode(child)
	end

	reportSummary()
	reportErrors()

	print(table.concat(output, "\n"))

	if root.fails > 0 then
		error(color.red(`{root.fails} test(s) failed`))
	end
end

local function finish(config: Config?)
	if config then
		options.colors = if config.colors ~= nil then config.colors else options.colors
		options.verbose = if config.verbose ~= nil then config.verbose else options.verbose
	end

	runTests()
	updateDescription(root)
	report()
end

local testCtor = setmetatable({
	skip = testSkip,
	only = testOnly,
}, {
	__call = function(_, ...)
		return test(...)
	end,
})

local describeCtor = setmetatable({
	skip = describeSkip,
	only = describeOnly,
}, {
	__call = function(_, ...)
		return describe(...)
	end,
})

return {
	test = testCtor :: ((name: string, callback: () -> ()) -> ()) & {
		skip: (name: string, callback: () -> ()) -> (),
		only: (name: string, callback: () -> ()) -> (),
	},
	describe = describeCtor :: ((name: string, callback: () -> ()) -> ()) & {
		skip: (name: string, callback: () -> ()) -> (),
		only: (name: string, callback: () -> ()) -> (),
	},
	skip = skip,
	only = only,
	finish = finish,
}
