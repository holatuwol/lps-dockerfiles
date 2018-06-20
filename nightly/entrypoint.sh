#!/bin/bash

. ${HOME}/common.sh

if [ "" == "${APP_SERVER}" ]; then
	APP_SERVER=tomcat
fi

. ${HOME}/app_${APP_SERVER}.sh

cd ${LIFERAY_HOME}
touch .liferay-home

if [ -f ${LIFERAY_HOME}/setup.sh ]; then
	cd ${LIFERAY_HOME}
	chmod u+x setup.sh
	./setup.sh
	cd -
fi

if [ "true" == "${IS_UPGRADE}" ]; then
	. ${HOME}/upgrade.sh $1
else
	. ${HOME}/bundle.sh $1
fi