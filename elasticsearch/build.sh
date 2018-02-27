for version in ../elasticsearch*; do
	if [ "../elasticsearch" == "${version}" ]; then
		continue
	fi

	cd $version
	./build.sh
done

cd ../elasticsearch