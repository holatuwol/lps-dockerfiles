#!/bin/bash

. ${HOME}/common.sh

if [ -f ${BUILD_MOUNT_POINT}/network.sh ]; then
	${BUILD_MOUNT_POINT}/network.sh
fi

set -o xtrace

cd ${LIFERAY_HOME}
touch .liferay-home

envreload $1
makesymlink
syncliferayhome
copyextras

if [ "true" == "${IS_UPGRADE}" ]; then
	. ${HOME}/upgrade.sh $1
else
	. ${HOME}/bundle.sh $1
fi