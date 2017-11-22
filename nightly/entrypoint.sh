#!/bin/bash

./common.sh $1

if [ "true" == "${IS_UPGRADE}" ]; then
	./upgrade.sh
else
	./bundle.sh
fi