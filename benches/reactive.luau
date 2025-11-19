local Charm = require("../packages/charm/src")
local bench = require("./bench")

local effect = Charm.effect
local reactive = Charm.reactive

do
	local value = reactive({ a = 1 })
	bench.run("track reactive property", function()
		effect(function()
			local _ = value.a
		end)
	end)
end

do
	local value = reactive({ a = 1 })
	bench.run("write reactive property", function()
		value.a += 1
	end)
end

for _, amount in { 10, 100, 1000 } do
	print("---")

	do
		local rawArray = table.create(amount, 1)
		local array = reactive(rawArray)

		bench.run(`track for loop, {amount} elements`, function()
			local sum = 0
			effect(function()
				for i = 1, #array do
					sum += array[i]
				end
			end)
		end)
	end

	do
		local rawArray = table.create(amount, 1)
		local array = reactive(rawArray)

		bench.run(`track iteration, {amount} elements`, function()
			local sum = 0
			effect(function()
				for _, x in array do
					sum += x
				end
			end)
		end)
	end

	do
		local rawArray = table.create(amount, 1)
		local array = reactive(rawArray)

		effect(function()
			local sum = 0
			for _, x in array do
				sum += x
			end
		end)

		bench.run(`track index mutation (1st only), {amount} elements`, function()
			array[1] += 1
		end)
	end

	do
		local rawArray = table.create(amount, 1)
		local array = reactive(rawArray)

		effect(function()
			local sum = 0
			for _, x in array do
				sum += x
			end
		end)

		bench.run(`track index mutation (all), {amount} elements`, function()
			for i = 1, #array do
				array[i] += 1
			end
		end)
	end
end
