curl -o bin/roblox.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.lua

rojo sourcemap dev.project.json -o sourcemap.json

luau-lsp analyze \
	--defs=bin/roblox.d.luau \
	--defs=bin/testez.d.luau \
	--flag:LuauFixIndexerSubtypingOrdering=true \
	--flag:LuauInstantiateInSubtyping=true \
	--flag:LuauTinyControlFlowAnalysis=true \
	--sourcemap=sourcemap.json \
	--ignore="**/_Index/**" src

selene src
stylua --check src
eslint src

rm bin/roblox.d.luau
