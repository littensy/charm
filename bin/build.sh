mkdir build

build() {
	cat > packages/default.project.json <<EOF
{"name":"$1","globIgnorePaths":["**/node_modules","**/package.json","**/wally.toml"],"tree":{"\$path":"$1"}}
EOF
	rojo build packages -o build/$1.rbxm
	rm -rf packages/default.project.json
}

build charm
build charm-sync
build react
build vide
