#!/bin/bash

. /home/liferay/common.sh

if [ "" == "${APP_SERVER}" ]; then
	APP_SERVER=tomcat
fi

. /home/liferay/app_${APP_SERVER}.sh

if [ -f ${LIFERAY_HOME}/setup.sh ]; then
	cd ${LIFERAY_HOME}
	chmod u+x setup.sh
	./setup.sh
	cd -
fi

if [ "true" == "${IS_UPGRADE}" ]; then
	. /home/liferay/upgrade.sh $1
else
	. /home/liferay/bundle.sh $1
fi