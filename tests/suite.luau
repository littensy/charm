local color = {
	white = function(text: string | number)
		return `\27[37;1m{text}\27[0m`
	end,
	gray = function(text: string | number)
		return `\27[30;1m{text}\27[0m`
	end,
	green = function(text: string | number)
		return `\27[32;1m{text}\27[0m`
	end,
	red = function(text: string | number)
		return `\27[31;1m{text}\27[0m`
	end,
	blue = function(text: string | number)
		return `\27[34;1m{text}\27[0m`
	end,
}

if script then
	local function prepend(prefix: string?): (string | number) -> string
		return function(text: string | number): string
			return if prefix then `{prefix} {text}` else `{text}`
		end
	end

	color.white = prepend()
	color.gray = prepend()
	color.green = prepend(utf8.char(0x1F7E2)) -- green circle
	color.red = prepend(utf8.char(0x1F534)) -- red circle
	color.blue = prepend(utf8.char(0x1F535)) -- blue circle
end

local WALL = color.gray("│")
local PASS = color.green("PASS") .. WALL
local FAIL = color.red("FAIL") .. WALL
local SKIP = color.blue("SKIP") .. WALL
local ERROR = color.red("ERROR") .. WALL

local results: { string } = {}
local stack: { string } = {}
local errors: { string } = {}

local skipDepth = 0
local skipCount = 0

local testsOk = 0
local testsFailed = 0
local testsSkipped = 0
local filesOk = 0
local filesFailed = 0

local start = os.clock()

local function log(result: string, index: number?)
	if index then
		table.insert(results, index, result)
	else
		table.insert(results, result)
	end
end

local function skip()
	skipDepth += 1
end

local function test(name: string, callback: () -> ())
	local path = color.gray(table.concat(stack, " > "))
	local line = color.red("-1:")

	if skipDepth > 0 then
		testsSkipped += 1
		skipCount += 1
		return
	end

	table.insert(stack, name)

	local success = xpcall(callback, function(err)
		line = color.red(`{debug.info(3, "l")}:`)
		table.insert(errors, `\n{ERROR} {path} > {line}{color.white(name)}\n{err}`)
	end)

	if success then
		testsOk += 1
	else
		testsFailed += 1
		log(`{FAIL} {path} {color.gray(">")} {line}{color.white(name)}`)
	end

	table.remove(stack)
end

local function describe(name: string, callback: () -> ())
	local path = if #stack > 0 then color.gray(table.concat(stack, " > ")) .. color.gray(" > ") else ""
	local index = #results + 1
	local start = os.clock()

	local initialTestsOk = testsOk
	local initialTestsFailed = testsFailed
	local initialSkipDepth = skipDepth

	skipCount = 0

	table.insert(stack, name)
	callback()
	table.remove(stack)

	skipDepth = initialSkipDepth

	local skippedEveryTest = initialTestsOk == testsOk and initialTestsFailed == testsFailed and skipCount > 0
	local passedEveryTest = testsFailed == initialTestsFailed

	local millis = string.format("%.2fms", (os.clock() - start) * 1000)
	local skips = if skipCount > 0 then color.blue(` ({skipCount} skipped) `) else " "

	if skippedEveryTest then
		filesOk += 1
		log(`{SKIP} {path .. color.white(name)}{skips}`, index)
	elseif passedEveryTest then
		filesOk += 1
		log(`{PASS} {path .. color.white(name)}{skips}{color.gray(millis)}`, index)
	else
		filesFailed += 1
		log(`{FAIL} {path .. color.white(name)}{skips}{color.gray(millis)}`, index)
	end
end

local function finish()
	local tests = testsOk + testsFailed + testsSkipped
	local files = filesOk + filesFailed
	local failed = testsFailed + filesFailed > 0
	local millis = math.round((os.clock() - start) * 1000)
	local output = {}

	table.insert(output, color.blue("Test Results\n"))

	for _, result in results do
		table.insert(output, result)
	end

	local redOrGreen: (string | number) -> string = if failed then color.red else color.green

	table.insert(output, "")
	table.insert(output, `Test Files  {redOrGreen(`{filesOk} passed`)} ({color.gray(`{files}`)})`)
	table.insert(output, `     Tests  {redOrGreen(`{testsOk} passed`)} ({color.gray(`{tests}`)})`)
	table.insert(output, `  Duration  {color.blue(`{millis}ms`)}`)

	print("\n" .. table.concat(output, "\n") .. "\n")

	if failed then
		print(`{color.red(`{testsFailed} errors:`)}\n{table.concat(errors, "\n")}\n`)
		error("Tests failed")
	end
end

return {
	test = test,
	describe = describe,
	skip = skip,
	finish = finish,
}
