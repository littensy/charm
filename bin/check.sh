curl -o bin/roblox.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

rojo sourcemap -o sourcemap.json

luau-lsp analyze \
	--defs=bin/roblox.d.luau \
	--flag:LuauFixIndexerSubtypingOrdering=true \
	--flag:LuauInstantiateInSubtyping=true \
	--sourcemap=sourcemap.json \
	--ignore="**/node_modules/**" \
	packages test benches

selene packages test benches

stylua --check packages test benches

pnpm eslint packages

rm bin/roblox.d.luau
