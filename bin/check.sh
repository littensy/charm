curl -o bin/roblox.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

rojo sourcemap -o sourcemap.json

luau-lsp analyze \
	--defs=bin/roblox.d.luau \
	--flag:LuauFixIndexerSubtypingOrdering=true \
	--sourcemap=sourcemap.json \
	--ignore="roblox_packages/**" \
	pkgs tests

selene pkgs tests

stylua --check pkgs tests

rm bin/roblox.d.luau
