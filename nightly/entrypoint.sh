#!/bin/bash

/home/liferay/common.sh $1

if [ "true" == "${IS_UPGRADE}" ]; then
	/home/liferay/upgrade.sh
else
	/home/liferay/bundle.sh
fi