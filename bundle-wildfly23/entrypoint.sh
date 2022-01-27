#!/bin/bash

. ${HOME}/common.sh

set -o xtrace

cd ${LIFERAY_HOME}
touch .liferay-home

envreload $1
makesymlink
syncliferayhome
copyextras

. ${HOME}/bundle.sh $1