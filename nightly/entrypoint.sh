#!/bin/bash

. /home/liferay/common.sh $1

if [ "true" == "${IS_UPGRADE}" ]; then
	LIFERAY_HOME=${LIFERAY_HOME} /home/liferay/upgrade.sh
else
	LIFERAY_HOME=${LIFERAY_HOME} /home/liferay/bundle.sh
fi