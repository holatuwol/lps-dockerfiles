#!/bin/bash

fix_db_address() {
	if [ -f ${LIFERAY_HOME}/portal-ext.properties ]; then
		BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)
		sed -i "/^jdbc/s/localhost/${BASE_IP}.1/g" ${LIFERAY_HOME}/portal-ext.properties
	fi
}

setup_wizard() {
	if [ -f ${HOME}/portal-setup-wizard.properties ] || [ -f ${LIFERAY_HOME}/portal-setup-wizard.properties ]; then
		return 0
	fi

	if [ -f ${LIFERAY_HOME}/portal-ext.properties ] && [ "" != "$(grep -F setup.wizard.enabled ${LIFERAY_HOME}/portal-ext.properties)" ]; then
		return 0
	fi

	local RELEASE_INFO_JAR=$(find ${LIFERAY_HOME} -name portal-kernel.jar)

	if [ "" == "${RELEASE_INFO_JAR}" ]; then
		RELEASE_INFO_JAR=$(find ${LIFERAY_HOME} -name portal-service.jar)
	fi

	echo 'public class Test { public static void main( String[] args ) { System.out.print(com.liferay.portal.kernel.util.ReleaseInfo.getVersion()); } }' > Test.java
	javac -classpath .:${RELEASE_INFO_JAR} Test.java

	LP_VERSION=$(java -classpath .:${RELEASE_INFO_JAR} Test)
	rm Test.java Test.class

	local LP_MAJOR_VERSION=$(echo "${LP_VERSION}" | cut -d'.' -f 1,2)

	echo "
setup.wizard.enabled=false
module.framework.properties.osgi.console=0.0.0.0:11311

web.server.display.node=true
users.reminder.queries.enabled=false
module.framework.properties.lpkg.index.validator.enabled=false

default.admin.screen.name=test
default.admin.password=${LIFERAY_PASSWORD}

lp.version=${LP_VERSION}
lp.version.major=${LP_MAJOR_VERSION}
" > ${HOME}/portal-setup-wizard.properties
}

start_bundle() {
	if [ "" == "${JVM_HEAP_SIZE}" ]; then
		JVM_HEAP_SIZE='2g'
	fi

	if [ "" == "${JVM_META_SIZE}" ]; then
		JVM_META_SIZE='512m'
	fi

	. ${HOME}/app_wildfly.sh

	if [ ! -f ${HOME}/.bundle ]; then
		fix_db_address
		setup_wizard
		prepare_server

		touch ${HOME}/.bundle
	fi

	start_server
}

start_bundle