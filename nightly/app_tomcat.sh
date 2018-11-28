#!/bin/bash

create_keystore() {
	if [ -f ${LIFERAY_HOME}/keystore ]; then
		return 0
	fi

	if [ -f /build/keystore ]; then
		return 0
	fi

	local BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)
	local COPY_KEYSTORE=

	if [ -f /build/server.crt ] && [ -f /build/server.key ]; then
		COPY_KEYSTORE=/build/server.crt

		cp /build/server.crt ${LIFERAY_HOME}/
		cp /build/server.key ${LIFERAY_HOME}/
	else
		cp /home/liferay/sslconfig.cnf.base ${LIFERAY_HOME}/sslconfig.cnf
		echo '' >> ${LIFERAY_HOME}/sslconfig.cnf

		seq 255 | awk '{ print "IP." $1 " = '${BASE_IP}'." $1 }' >> ${LIFERAY_HOME}/sslconfig.cnf
		echo "IP.256 = 127.0.0.1" >> ${LIFERAY_HOME}/sslconfig.cnf

		echo | openssl req -config ${LIFERAY_HOME}/sslconfig.cnf -new -sha256 -newkey rsa:2048 \
			-nodes -keyout ${LIFERAY_HOME}/server.key -x509 -days 365 \
			-out ${LIFERAY_HOME}/server.crt
	fi

	openssl pkcs12 -export \
		-in ${LIFERAY_HOME}/server.crt -inkey ${LIFERAY_HOME}/server.key -passin pass:'' \
		-out ${LIFERAY_HOME}/server.p12 -passout pass:'' -name tomcat

	keytool -importkeystore -destkeypass changeit \
		-deststorepass changeit -destkeystore ${LIFERAY_HOME}/keystore \
		-srckeystore ${LIFERAY_HOME}/server.p12 -srcstorepass '' -srcstoretype PKCS12 -alias tomcat

	if [ -d /build/ ] && [ "" == "${COPY_KEYSTORE}" ]; then
		cp -f ${LIFERAY_HOME}/server.crt /build/
		cp -f ${LIFERAY_HOME}/server.key /build/
		cp -f ${LIFERAY_HOME}/keystore /build/
	fi
}

downloadbranchbuild() {
	# Make sure there is a build on the archive mirror for our branch

	if [ "" == "$BRANCH_ARCHIVE_MIRROR" ]; then
		return 0
	fi

	BUILD_NAME=$(curl -s --connect-timeout 2 $BRANCH_ARCHIVE_MIRROR/ | grep -o '<a href="'${SHORT_NAME}'-[0-9]*.tar.[xg]z">' | cut -d'"' -f 2 | sort | tail -1)

	if [ "" == "$BUILD_NAME" ]; then
		echo "Failed to find ${SHORT_NAME} on ${BRANCH_ARCHIVE_MIRROR}"
		return 0
	fi

	# Set the hash as an environment variable

	if [ -f /rdbuild/${BUILD_NAME} ] && [ -f /rdbuild/${BUILD_NAME}.githash ]; then
		NEW_BASELINE=$(cat /rdbuild/${BUILD_NAME}.githash)
	else
		BUILD_LOG=$(echo $BUILD_NAME | cut -d'.' -f 1).log
		UPDATE_TIME=$(echo $BUILD_NAME | cut -d'.' -f 1 | cut -d'-' -f 2)
		NEW_BASELINE=$(curl -r 0-49 -s ${BRANCH_ARCHIVE_MIRROR}/${BUILD_LOG} | tail -1)
	fi

	# Skip downloading the actual build if we already have it

	if [ -d /rdbuild ]; then
		if [ -f /rdbuild/${BUILD_NAME} ]; then
			cp /rdbuild/${BUILD_NAME} ${LIFERAY_HOME}/
			return 0
		fi

		find /rdbuild -name "${SHORT_NAME}*.tar.gz*" -exec rm {} +
		find /rdbuild -name "${SHORT_NAME}*.tar.xz*" -exec rm {} +
	fi

	# Download the build if we haven't done so already, making
	# sure to clean up past builds to not take up too much space

	echo "Downloading snapshot for $SHORT_NAME ($NEW_BASELINE)"

	getbuild "${BRANCH_ARCHIVE_MIRROR}/${BUILD_NAME}" "${BUILD_NAME}"

	if [ -d /rdbuild ]; then
		cp ${LIFERAY_HOME}/${BUILD_NAME} /rdbuild/
	fi
}

downloadbranchmirror() {
	local REQUEST_URL=

	if [[ "$BASE_BRANCH" == ee-* ]] || [[ "$BASE_BRANCH" == *-private ]]; then
		if [ "" == "$LIFERAY_FILES_MIRROR" ]; then
			return 0
		fi

		REQUEST_URL="$LIFERAY_FILES_MIRROR/private/ee/portal/snapshot-$BASE_BRANCH/latest/"
	else
		if [ "" == "$LIFERAY_RELEASES_MIRROR" ]; then
			LIFERAY_RELEASES_MIRROR=https://releases.liferay.com
		fi

		REQUEST_URL="$LIFERAY_RELEASES_MIRROR/portal/snapshot-$BASE_BRANCH/latest/"
	fi

	local ARTIFACT_NAME=$(curl -s --connect-timeout 2 $FILES_CREDENTIALS $REQUEST_URL | grep -o '<a href="liferay-portal-tomcat-[^"]*\.\(7z\|zip\)">' | cut -d'"' -f 2)

	REQUEST_URL="${REQUEST_URL}${ARTIFACT_NAME}"
	BUILD_NAME=$(echo ${ARTIFACT_NAME} | sed "s/liferay-portal-tomcat-${BASE_BRANCH}/${SHORT_NAME}/g")

	local ARCHIVE_NAME=$(echo ${ARTIFACT_NAME} | sed "s/liferay-portal-tomcat-${BASE_BRANCH}/${SHORT_NAME}-$(date '+%Y%m%d')/g")

	if [ -d /rdbuild ]; then
		if [ -f /rdbuild/${ARCHIVE_NAME} ]; then
			cp "/rdbuild/${ARCHIVE_NAME}" "${LIFERAY_HOME}/${BUILD_NAME}"
		else
			find /rdbuild -name "${SHORT_NAME}*.zip*" -exec rm {} +
			find /rdbuild -name "${SHORT_NAME}*.7z*" -exec rm {} +
		fi
	fi

	if [ ! -f "${LIFERAY_HOME}/${BUILD_NAME}" ]; then
		echo "Downloading snapshot for $SHORT_NAME"

		getbuild "${REQUEST_URL}" "${BUILD_NAME}"
	fi

	if [[ $BUILD_NAME == *.zip ]]; then
		if [ "" != "$(unzip -l ${LIFERAY_HOME}/${BUILD_NAME} | grep -F .githash)" ]; then
			NEW_BASELINE=$(unzip -c -qq ${LIFERAY_HOME}/${BUILD_NAME} liferay-portal-${BASE_BRANCH}/.githash)
		else
			NEW_BASELINE=$(unzip -c -qq ${LIFERAY_HOME}/${BUILD_NAME} liferay-portal-${BASE_BRANCH}/git-commit)
		fi
	else
		if [ "" != "$(7z l ${LIFERAY_HOME}/${BUILD_NAME} | grep -F .githash)" ]; then
			NEW_BASELINE=$(7z -so e ${LIFERAY_HOME}/${BUILD_NAME} liferay-portal-${BASE_BRANCH}/.githash)
		else
			NEW_BASELINE=$(7z -so e ${LIFERAY_HOME}/${BUILD_NAME} liferay-portal-${BASE_BRANCH}/git-commit)
		fi
	fi

	if [ -d /rdbuild ]; then
		cp "${LIFERAY_HOME}/${BUILD_NAME}" "/rdbuild/${ARCHIVE_NAME}"
	fi
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

	getbuild "${REQUEST_URL}" "${BUILD_NAME}"

	if [ -d /release ]; then
		cp ${LIFERAY_HOME}/${BUILD_NAME} /release/${BUILD_CANDIDATE}
	fi
}

downloadtag() {
	NEW_BASELINE=$BASE_TAG
	BUILD_NAME=${BASE_TAG}.tar.gz

	if [ -f /rdbuild/${BUILD_NAME} ]; then
		cp /rdbuild/${BUILD_NAME} ${LIFERAY_HOME}/
		return 0
	fi

	echo "Downloading snapshot for $BASE_TAG"
	getbuild "${TAG_ARCHIVE_MIRROR}/${BUILD_NAME}"

	if [ -d /rdbuild ]; then
		cp "${LIFERAY_HOME}/${BUILD_NAME}" /rdbuild/
	fi
}

extract() {
	# Figure out if we need to untar the build, based on whether the
	# baseline hash has changed

	cd ${LIFERAY_HOME}

	echo "Build name: $BUILD_NAME"

	if [[ "$BUILD_NAME" == *.tar.gz ]]; then
		tar -zxf ${BUILD_NAME}
	elif [[ "$BUILD_NAME" == *.tar.xz ]]; then
		unxz ${BUILD_NAME}
		tar -xf ${BUILD_NAME}
	elif [[ "$BUILD_NAME" == *.zip ]]; then
		unzip -qq "${BUILD_NAME}"
	elif [[ "$BUILD_NAME" == *.7z ]]; then
		7z x "${BUILD_NAME}"
	fi

	local OLD_LIFERAY_HOME=$(find . -type d -name '.liferay-home' | sort | head -1)

	if [ "" == "$OLD_LIFERAY_HOME" ]; then
		local OLD_CATALINA_HOME=$(find . -type d -name 'tomcat*' | sort | head -1)

		if [ "" != "${OLD_CATALINA_HOME}" ]; then
			OLD_LIFERAY_HOME=$(dirname "$OLD_CATALINA_HOME")
		fi
	fi

	if [ "" == "$OLD_LIFERAY_HOME" ]; then
		find . -type d
		echo "Unable to find LIFERAY_HOME for archive of ${BUILD_NAME}"
		exit 1
	fi

	echo "Moving files from ${OLD_LIFERAY_HOME} to ${PWD}"

	for file in $(find $OLD_LIFERAY_HOME -mindepth 1 -maxdepth 1); do
		if [ ! -e "$(basename $file)" ]; then
			mv $file .
		fi
	done

	rm -rf $OLD_LIFERAY_HOME

	if [ "" != "$BUILD_NAME" ]; then
		rm $BUILD_NAME
	fi

	cd -
}

makesymlink() {
	if [ -h ${LIFERAY_HOME}/tomcat ]; then
		CATALINA_HOME=${LIFERAY_HOME}/tomcat
		return 0
	fi

	CATALINA_HOME=$(find ${LIFERAY_HOME} -mindepth 1 -maxdepth 1 -name 'tomcat*')
	echo "Adding symbolic link to $CATALINA_HOME"
	ln -s ${CATALINA_HOME} ${LIFERAY_HOME}/tomcat
	CATALINA_HOME=${LIFERAY_HOME}/tomcat
}

setup_ssl() {
	if [ -d /opt/ibm/java ]; then
		return 0
	fi

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

	JVM_HEAP_SIZE="${JVM_HEAP_SIZE}" JPDA_ADDRESS='0.0.0.0:8000' ${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run
}