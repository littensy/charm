curl -o bin/roblox.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

rojo sourcemap -o sourcemap.json

luau-lsp analyze \
	--defs=bin/roblox.d.luau \
	--flag:LuauFixIndexerSubtypingOrdering=true \
	--sourcemap=sourcemap.json \
	--ignore="**/_Index/**" \
	packages tests

selene packages tests

stylua --check packages tests

eslint packages

rm bin/roblox.d.luau
