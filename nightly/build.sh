#!/bin/bash

for version in ../nightly-*; do
	cd $version
	./build.sh
done

cd ../nightly