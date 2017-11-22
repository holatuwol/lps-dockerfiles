#!/bin/bash

./common.sh

if [ "upgrade" == "$1" ]; then
	./upgrade.sh
else
	./bundle.sh $@
fi