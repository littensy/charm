_G.__ROACT_17_MOCK_SCHEDULER__ = true

local Package = script:FindFirstAncestor("__tests__").Parent

local React = require(Package.modules.React)
local ReactRoblox = require(Package.modules.ReactRoblox)

type RenderedHook<Props, Result> = {
	result: Result,
	rerender: (Props?) -> (),
	unmount: () -> (),
}

local function renderHook<Props, Result>(callback: (Props) -> Result, props: Props?): RenderedHook<Props, Result>
	local root = ReactRoblox.createLegacyRoot(Instance.new("Folder"))
	local hook = {}

	local function Component(props)
		hook.result = callback(props)
	end

	function hook.rerender(newProps)
		props = newProps or props
		ReactRoblox.act(function()
			root:render(React.createElement(Component, props))
		end)
	end

	function hook.unmount()
		ReactRoblox.act(function()
			root:unmount()
		end)
	end

	ReactRoblox.act(function()
		hook.rerender(props)
	end)

	return hook
end

return renderHook
