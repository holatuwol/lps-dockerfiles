#!/bin/bash

copyextras() {
	return 0
}

syncliferayhome() {
	if [ -f /build/portal-ext.properties ]; then
		ln -s /build/portal-ext.properties ${LIFERAY_HOME}/
	fi

	if [ -d "/build/drivers" ]; then
		local GLOBAL_LIB=$(dirname $(find ${LIFERAY_HOME} -name portlet.jar))

		cp -f "/build/drivers/*" "${GLOBAL_LIB}"
	fi

	if [ -d /build ]; then
		mkdir -p ${LIFERAY_HOME}/osgi

		for file in /build/osgi/*; do
			if [ -d ${file} ] && [ "state" != "$(basename ${file})" ]; then
				if [ "static" == "$(basename ${file})" ]; then
					cp -R ${file} ${LIFERAY_HOME}/osgi/
				else
					ln -s ${file} ${LIFERAY_HOME}/osgi/
				fi
			fi
		done

		ln -s /build/deploy ${LIFERAY_HOME}/
		ln -s /build/tomcat*/ ${LIFERAY_HOME}/tomcat
	fi

	if [ -d /opt/ibm/java ]; then
		rm -f /opt/liferay/tomcat/webapps/ROOT/WEB-INF/classes/META-INF/MANIFEST.MF
	fi
}

envreload() {
	if [ -f ${HOME}/.oldenv ]; then
		echo 'Loading old environment variables'
		cat ${HOME}/.oldenv

		source ${HOME}/.oldenv

		return 0
	fi

	if [ "" == "${BUILD_MOUNT_POINT}" ]; then
		BUILD_MOUNT_POINT='/build'
	fi

	if [ "" == "${LIFERAY_FILES_EE_FOLDER}" ]; then
		LIFERAY_FILES_EE_FOLDER='private/ee'
	fi

	# Set a random password

	if [ "" == "${LIFERAY_PASSWORD}" ]; then
		LIFERAY_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 30 | head -n 1)
	fi

	echo 'Saving environment variables'
	env | grep -v '^\(OLD\)*PWD=' | grep -v '=$' | tee ${HOME}/.oldenv
}

javahome() {
	if [ "" != "${JAVA_HOME}" ]; then
		return 0
	fi

	if [ -d /usr/lib/jvm/ ]; then
		JAVA_HOME=/usr/lib/jvm/$(ls -1 /usr/lib/jvm/ | tail -1)
	fi
}

makesymlink() {
	if [ -h ${LIFERAY_HOME}/tomcat ]; then
		CATALINA_HOME=${LIFERAY_HOME}/tomcat
		return 0
	fi

	CATALINA_HOME=$(find ${LIFERAY_HOME} -mindepth 1 -maxdepth 1 -name 'tomcat*')

	if [ "" != "${CATALINA_HOME}" ]; then
		echo "Adding symbolic link to $CATALINA_HOME"
		ln -s ${CATALINA_HOME} ${LIFERAY_HOME}/tomcat
		CATALINA_HOME=${LIFERAY_HOME}/tomcat
	fi
}

javahome