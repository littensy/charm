rm -f src/*/*.tgz

for package in src/*; do
	(cd $package && pnpm pack)
done

for tarball in src/*/*.tgz; do
	echo "pnpm add $(realpath $tarball)"
done
