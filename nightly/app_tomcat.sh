#!/bin/bash

create_keystore() {
	if [ -f ${LIFERAY_HOME}/keystore ]; then
		return 0
	fi

	if [ -f /build/keystore ]; then
		return 0
	fi

	local BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)

	cp /home/liferay/sslconfig.cnf.base ${LIFERAY_HOME}/sslconfig.cnf
	echo '' >> ${LIFERAY_HOME}/sslconfig.cnf

	seq 255 | awk '{ print "IP." $1 " = '${BASE_IP}'." $1 }' >> ${LIFERAY_HOME}/sslconfig.cnf
	echo "IP.256 = 127.0.0.1" >> ${LIFERAY_HOME}/sslconfig.cnf

	echo | openssl req -config ${LIFERAY_HOME}/sslconfig.cnf -new -sha256 -newkey rsa:2048 \
		-nodes -keyout ${LIFERAY_HOME}/server.key -x509 -days 365 \
		-out ${LIFERAY_HOME}/server.crt

	openssl pkcs12 -export \
		-in ${LIFERAY_HOME}/server.crt -inkey ${LIFERAY_HOME}/server.key -passin pass:'' \
		-out ${LIFERAY_HOME}/server.p12 -passout pass:'' -name tomcat

	keytool -importkeystore -destkeypass changeit \
		-deststorepass changeit -destkeystore ${LIFERAY_HOME}/keystore \
		-srckeystore ${LIFERAY_HOME}/server.p12 -srcstorepass '' -srcstoretype PKCS12 -alias tomcat

	if [ -d /build/ ]; then
		cp -f ${LIFERAY_HOME}/server.crt /build/
		cp -f ${LIFERAY_HOME}/keystore /build/
	fi
}

downloadbranchbuild() {
	# Make sure there is a build on the archive mirror for our branch

	if [ "" == "$BRANCH_ARCHIVE_MIRROR" ]; then
		return 0
	fi

	BUILD_NAME=$(curl -s --connect-timeout 2 $BRANCH_ARCHIVE_MIRROR/ | grep -o '<a href="'${SHORT_NAME}'-[0-9]*.tar.gz">' | cut -d'"' -f 2 | sort | tail -1)

	if [ "" == "$BUILD_NAME" ]; then
		return 0
	fi

	# Acquire the hash and make sure we have it

	BUILD_LOG=$(echo $BUILD_NAME | cut -d'.' -f 1).log
	UPDATE_TIME=$(echo $BUILD_NAME | cut -d'.' -f 1 | cut -d'-' -f 2)
	NEW_BASELINE=$(curl -r 0-49 -s ${BRANCH_ARCHIVE_MIRROR}/${BUILD_LOG} | tail -1)

	# Download the build if we haven't done so already, making
	# sure to clean up past builds to not take up too much space

	echo "Downloading snapshot for $SHORT_NAME ($NEW_BASELINE)"

	getbuild "${BRANCH_ARCHIVE_MIRROR}/${BUILD_NAME}"
}

downloadbranchmirror() {
	local REQUEST_URL=

	if [[ "$BASE_BRANCH" == ee-* ]] || [[ "$BASE_BRANCH" == *-private ]]; then
		if [ "" == "$LIFERAY_FILES_MIRROR" ]; then
			return 0
		fi

		REQUEST_URL="$LIFERAY_FILES_MIRROR/private/ee/portal/upstream-$BASE_BRANCH/latest/liferay-portal-tomcat-$BASE_BRANCH.zip"
	else
		if [ "" == "$LIFERAY_RELEASES_MIRROR" ]; then
			LIFERAY_RELEASES_MIRROR=https://releases.liferay.com
		fi

		REQUEST_URL="$LIFERAY_RELEASES_MIRROR/portal/upstream-$BASE_BRANCH/latest/liferay-portal-tomcat-$BASE_BRANCH.zip"
	fi

	BUILD_NAME="$SHORT_NAME.zip"

	echo "Downloading snapshot for $SHORT_NAME"

	getbuild $REQUEST_URL ${BUILD_NAME}
	NEW_BASELINE=$(unzip -c -qq ${LIFERAY_HOME}/${BUILD_NAME} liferay-portal-${BASE_BRANCH}/.githash)
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

	echo "Identifying build candidate (release) via ${REQUEST_URL}"

	BUILD_NAME=${RELEASE_ID}.zip
	local BUILD_CANDIDATE=$(curl -s --connect-timeout 2 $REQUEST_URL | grep -o '<a href="[^"]*tomcat-[^"]*.zip">' | grep -vF 'jre' | cut -d'"' -f 2 | sort | tail -1)

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
	# Figure out if we need to untar the build, based on whether the
	# baseline hash has changed

	cd ${LIFERAY_HOME}

	echo "Build name: $BUILD_NAME"

	if [[ "$BUILD_NAME" == *.tar.gz ]]; then
		tar -zxf ${BUILD_NAME}
	elif [[ "$BUILD_NAME" == *.zip ]]; then
		unzip -qq "${BUILD_NAME}"
	fi

	local OLD_CATALINA_HOME=$(find . -type d -name 'tomcat*' | sort | head -1)

	if [ "" != "$OLD_CATALINA_HOME" ]; then
		local OLD_LIFERAY_HOME=$(dirname "$OLD_CATALINA_HOME")

		if [ "." != "$OLD_LIFERAY_HOME" ]; then
			for file in $(find $OLD_LIFERAY_HOME -mindepth 1 -maxdepth 1); do
				if [ ! -e "$(basename $file)" ]; then
					mv $file .
				fi
			done

			rm -rf $OLD_LIFERAY_HOME
		fi
	fi

	if [ "" != "$BUILD_NAME" ]; then
		rm $BUILD_NAME
	fi

	cd -
}

makesymlink() {
	if [ -h ${LIFERAY_HOME}/tomcat ]; then
		return 0
	fi

	CATALINA_HOME=$(find ${LIFERAY_HOME} -mindepth 1 -maxdepth 1 -name 'tomcat*')
	echo "Adding symbolic link to $CATALINA_HOME"
	ln -s $CATALINA_HOME ${LIFERAY_HOME}/tomcat

	cp -f ${LIFERAY_HOME}/setenv.sh ${LIFERAY_HOME}/bin/
}

setup_ssl() {
	if [ -f ${CATALINA_HOME}/cacerts ]; then
		return 0
	fi

	cp ${JAVA_HOME}/jre/lib/security/cacerts ${CATALINA_HOME}/
	keytool -import -noprompt -keystore ${CATALINA_HOME}/cacerts -storepass changeit -file ${LIFERAY_HOME}/server.crt -alias client

	if [ -f ${CATALINA_HOME}/conf/server.xml.http ]; then
		rm -f ${CATALINA_HOME}/conf/server.xml ${CATALINA_HOME}/conf/server.xml.https
		mv ${CATALINA_HOME}/conf/server.xml.http ${CATALINA_HOME}/conf/server.xml
	fi

	sed -n '1,/ port="8443"/p' ${CATALINA_HOME}/conf/server.xml | sed '$d' | sed '$d' > ${CATALINA_HOME}/conf/server.xml.https

	if [ "" != "$(grep -F 'Apache Tomcat Version 9' ${CATALINA_HOME}/RELEASE-NOTES)" ]; then
		sed -n '/ port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"/,/<Certificate/p' ${CATALINA_HOME}/conf/server.xml | sed '$d' >> ${CATALINA_HOME}/conf/server.xml.https
		echo '<Certificate certificateKeystoreFile="'${LIFERAY_HOME}'/keystore" type="RSA" />' >> ${CATALINA_HOME}/conf/server.xml.https
		echo '</SSLHostConfig>' >> ${CATALINA_HOME}/conf/server.xml.https
		echo '</Connector>' >> ${CATALINA_HOME}/conf/server.xml.https
	else
		sed -n '/ port="8443"/,/-->/p' ${CATALINA_HOME}/conf/server.xml | sed '$d' | sed '$d' >> ${CATALINA_HOME}/conf/server.xml.https
		echo 'keystoreFile="'${LIFERAY_HOME}'/keystore" keystorePass="changeit"' >> ${CATALINA_HOME}/conf/server.xml.https
		sed -n '/ port="8443"/,/-->/p' ${CATALINA_HOME}/conf/server.xml | tail -2 | head -1 >> ${CATALINA_HOME}/conf/server.xml.https
	fi

	echo '<!--' >> ${CATALINA_HOME}/conf/server.xml.https
	sed -n '/ port="8443"/,$p' ${CATALINA_HOME}/conf/server.xml >> ${CATALINA_HOME}/conf/server.xml.https

	mv ${CATALINA_HOME}/conf/server.xml ${CATALINA_HOME}/conf/server.xml.http

	cp -f ${CATALINA_HOME}/conf/server.xml.https ${CATALINA_HOME}/conf/server.xml
}

startserver() {
	sed -i.bak "s/-Xms[^ ]*/-Xms${JVM_HEAP_SIZE}/g" ${LIFERAY_HOME}/tomcat/bin/setenv.sh
	sed -i.bak "s/-Xmx[^ ]*/-Xmx${JVM_HEAP_SIZE}/g" ${LIFERAY_HOME}/tomcat/bin/setenv.sh

	JPDA_ADDRESS='0.0.0.0:8000' ${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run
}