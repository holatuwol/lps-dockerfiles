#!/bin/bash

for version in ../nightly-*; do
	cp -f build.sh ${version}
	cd ${version}
	./build.sh $@
	cd -
done