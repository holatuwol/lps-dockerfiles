#!/bin/bash

. /home/liferay/common.sh $1

if [ -f ${LIFERAY_HOME}/setup.sh ]; then
	cd ${LIFERAY_HOME}
	chmod u+x setup.sh
	./setup.sh
	cd -
fi

if [ "true" == "${IS_UPGRADE}" ]; then
	LIFERAY_HOME=${LIFERAY_HOME} /home/liferay/upgrade.sh
else
	LIFERAY_HOME=${LIFERAY_HOME} /home/liferay/bundle.sh
fi