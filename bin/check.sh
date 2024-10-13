curl -o bin/roblox.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.lua

rojo sourcemap -o sourcemap.json

check() {
	echo "Checking $1"

	luau-lsp analyze \
		--defs=bin/roblox.d.luau \
		--defs=bin/testez.d.luau \
		--flag:LuauFixIndexerSubtypingOrdering=true \
		--flag:LuauInstantiateInSubtyping=true \
		--sourcemap=sourcemap.json \
		--ignore="**/_Index/**" \
		$1

	selene $1
	stylua --check $1
}

eslint src
check src/*/src
check tests

rm bin/roblox.d.luau
