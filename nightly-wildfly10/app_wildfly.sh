#!/bin/bash

addmodulexml() {
	echo '<?xml version="1.0"?>

<module xmlns="urn:jboss:module:1.0" name="com.liferay.portal">
<resources>' > ${WILDFLY_HOME}/modules/com/liferay/portal/main/module.xml

	for file in $(ls -1 ${WILDFLY_HOME}/modules/com/liferay/portal/main/); do
		if [[ ${file} == *.jar ]] && [ "${file}" != "support-tomcat.jar" ]; then
			echo '<resource-root path="'${file}'" />' >> ${WILDFLY_HOME}/modules/com/liferay/portal/main/module.xml
		fi
	done

	echo '</resources>
<dependencies>
<module name="javax.api" />
<module name="javax.mail.api" />
<module name="javax.servlet.api" />
<module name="javax.servlet.jsp.api" />
<module name="javax.transaction.api" />
</dependencies>
</module>' >> ${WILDFLY_HOME}/modules/com/liferay/portal/main/module.xml
}

create_keystore() {
	return 0
}

downloadbranchbuild() {
	return 0
}

downloadbranchmirror() {
	return 0
}

downloadreleasebuild() {
	local REQUEST_URL=

	if [ "" == "$RELEASE_ID" ]; then
		if [ -d $LIFERAY_HOME/patches ] || [ "" != "$PATCH_ID" ]; then
			RELEASE_ID=7.0.10
		else
			RELEASE_ID=7.0.0-ga1
		fi
	fi

	if [[ 10 -le $(echo "$RELEASE_ID" | cut -d'.' -f 3 | cut -d'-' -f 1) ]]; then
		downloadlicense
	else
		REQUEST_URL="$LIFERAY_RELEASES_MIRROR/portal/${RELEASE_ID}/"
	fi

	BASE_REQUEST_URL=${REQUEST_URL}

	REQUEST_URL=${BASE_REQUEST_URL}
	downloadreleasebuildartifact '.war' ${RELEASE_ID}.war
	BUILD_NAMES="${BUILD_NAMES} ${BUILD_NAME}"

	REQUEST_URL=${BASE_REQUEST_URL}
	downloadreleasebuildartifact '-dependencies-' ${RELEASE_ID}-dependencies.zip
	BUILD_NAMES="${BUILD_NAMES} ${BUILD_NAME}"

	REQUEST_URL=${BASE_REQUEST_URL}
	downloadreleasebuildartifact '-osgi-' ${RELEASE_ID}-osgi.zip
	BUILD_NAMES="${BUILD_NAMES} ${BUILD_NAME}"
}

downloadreleasebuildartifact() {
	echo "Identifying build candidate (release) via ${REQUEST_URL}"

	BUILD_NAME=${2}
	local BUILD_CANDIDATE=$(curl -s --connect-timeout 2 $REQUEST_URL | grep -o '<a href=".*'${1}'.*">' | cut -d'"' -f 2 | sort | tail -1)

	if [ "" == "$BUILD_CANDIDATE" ]; then
		echo "Unable to identify build candidate (maybe you forgot to connect to a VPN)"
		return 0
	fi

	echo $BUILD_CANDIDATE

	if [ -f /release/${BUILD_CANDIDATE} ]; then
		echo "Using already downloaded ${BUILD_CANDIDATE}"

		if [ ! -f ${LIFERAY_HOME}/${BUILD_CANDIDATE} ]; then
			cp /release/${BUILD_CANDIDATE} ${LIFERAY_HOME}/${BUILD_NAME}
		fi

		return 0
	fi

	REQUEST_URL="${REQUEST_URL}${BUILD_CANDIDATE}"

	BUILD_TIMESTAMP=$(echo $BUILD_CANDIDATE | grep -o "[0-9]*.zip" | cut -d'.' -f 1)

	echo "Downloading $RELEASE_ID release (used for patching)"

	getbuild $REQUEST_URL $BUILD_NAME

	if [ -d /release ]; then
		cp ${LIFERAY_HOME}/${BUILD_NAME} /release/${BUILD_CANDIDATE}
	fi
}

extract() {
	cd ${LIFERAY_HOME}

	mkdir -p ${WILDFLY_HOME}/standalone/deployments/ROOT.war
	mkdir -p ${WILDFLY_HOME}/modules/com/liferay/portal/main/

	unzip -qq ${RELEASE_ID}-osgi.zip

	if [ -d liferay-*/osgi ]; then
		mv liferay-*/osgi .
		rmdir liferay-*
	else
		mv liferay-* osgi
	fi

	rm ${RELEASE_ID}-osgi.zip

	cd ${WILDFLY_HOME}/modules/com/liferay/portal/main/
	unzip -jqq ${LIFERAY_HOME}/${RELEASE_ID}-dependencies.zip

	addmodulexml

	cp ${LIFERAY_HOME}/osgi/core/com.liferay.osgi.service.tracker.collections*.jar .

	if [ ! -f com.liferay.osgi.service.tracker.collections.jar ]; then
		mv com.liferay.osgi.service.tracker.collections*.jar com.liferay.osgi.service.tracker.collections.jar
	fi

	rm ${LIFERAY_HOME}/${RELEASE_ID}-dependencies.zip

	cd ${WILDFLY_HOME}/standalone/deployments/ROOT.war
	unzip -qq ${LIFERAY_HOME}/${RELEASE_ID}.war
	rm ${LIFERAY_HOME}/${RELEASE_ID}.war
	touch ${WILDFLY_HOME}/standalone/deployments/ROOT.war.dodeploy
}

makesymlink() {
	return 0
}

setup_ssl() {
	return 0
}

startserver() {
	sed -i.bak "s/-Xms[^ ]*/-Xms${JVM_HEAP_SIZE}/g" ${WILDFLY_HOME}/bin/standalone.sh
	sed -i.bak "s/-Xmx[^ ]*/-Xmx${JVM_HEAP_SIZE}/g" ${WILDFLY_HOME}/bin/standalone.sh

	/opt/jboss/wildfly/bin/standalone.sh -b 0.0.0.0 --debug 8000
}