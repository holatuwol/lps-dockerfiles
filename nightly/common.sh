#!/bin/bash

checkservicepack() {
	if [ "" != "${RELEASE_ID}" ]; then
		echo "Already identified release as ${RELEASE_ID}"
		return 0
	fi

	if [ "" == "${PATCH_ID}" ]; then
		return 0
	fi

	echo "Checking service pack for ${PATCH_ID}"

	declare -A SERVICE_PACKS

	SERVICE_PACKS[portal-45]=6.2.10.12
	SERVICE_PACKS[portal-63]=6.2.10.13
	SERVICE_PACKS[portal-69]=6.2.10.14
	SERVICE_PACKS[portal-77]=6.2.10.15
	SERVICE_PACKS[portal-114]=6.2.10.16
	SERVICE_PACKS[portal-121]=6.2.10.17
	SERVICE_PACKS[portal-128]=6.2.10.18
	SERVICE_PACKS[portal-138]=6.2.10.19
	SERVICE_PACKS[portal-148]=6.2.10.20
	SERVICE_PACKS[portal-154]=6.2.10.21

	SERVICE_PACKS[de-7]=7.0.10.1
	SERVICE_PACKS[de-12]=7.0.10.2
	SERVICE_PACKS[de-14]=7.0.10.3
	SERVICE_PACKS[de-22]=7.0.10.4
	SERVICE_PACKS[de-30]=7.0.10.5
	SERVICE_PACKS[de-32]=7.0.10.6

	if [[ ${PATCH_ID} == liferay-fix-pack-portal-* ]]; then
		closestservicepack $(echo "${PATCH_ID}" | cut -d'-' -f 4-)
	elif [[ ${PATCH_ID} == liferay-fix-pack-* ]]; then
		closestservicepack $(echo "${PATCH_ID}" | cut -d'-' -f 4,5)
	else
		closestservicepack ${PATCH_ID}
	fi
}

closestservicepack() {
	RELEASE_ID=${SERVICE_PACKS[${1}]}

	if [ "" != "${RELEASE_ID}" ]; then
		return 0
	fi

	if [[ "${1}" == portal-* ]]; then
		for id in $(seq $(echo "${1}" | cut -d'-' -f 2) | tac); do
			RELEASE_ID=${SERVICE_PACKS[portal-${id}]}

			if [ "" != "${RELEASE_ID}" ]; then
				return 0
			fi
		done
	fi

	if [[ "${1}" == de-* ]]; then
		for id in $(seq $(echo "${1}" | cut -d'-' -f 2) | tac); do
			RELEASE_ID=${SERVICE_PACKS[de-${id}]}

			if [ "" != "${RELEASE_ID}" ]; then
				return 0
			fi
		done
	fi

	if [[ "${1}" == *-7010 ]]; then
		RELEASE_ID=7.0.10
		return 0
	fi

	if [[ "${1}" == *-6210 ]]; then
		RELEASE_ID=6.2.10
		return 0
	fi
}

computername() {
	if [ "" != "$(grep -F '-Denv.COMPUTERNAME=' ${LIFERAY_HOME}/tomcat/bin/setenv.sh)" ]; then
		return 0
	fi

	if [ "" == "${RELEASE_ID}" ]; then
		return 0
	fi

	local COMPUTERNAME="${RELEASE_ID}"

	if [ "" != "${PATCH_ID}" ]; then
		COMPUTERNAME="${PATCH_ID}"
	fi

	echo '' >> ${LIFERAY_HOME}/tomcat/bin/setenv.sh
	echo 'CATALINA_OPTS="${CATALINA_OPTS} -Denv.COMPUTERNAME='${COMPUTERNAME}'"' >> ${LIFERAY_HOME}/tomcat/bin/setenv.sh
	echo 'export CATALINA_OPTS' >> ${LIFERAY_HOME}/tomcat/bin/setenv.sh
}

copyextras() {
	if [ -d "/build/drivers" ]; then
		rsync -aq "/build/drivers/" "${LIFERAY_HOME}/tomcat/lib/ext/"
	fi

	if [ ! -d /build/patches ] && [ ! -d "${LIFERAY_HOME}/patching-tool" ]; then
		if [ "" == "$RELEASE_ID" ] || [[ 10 -lt $(echo "$RELEASE_ID" | cut -d'.' -f 3 | cut -d'-' -f 1) ]]; then
			echo "Not an EE release, so patches will not be installed"
			return 0
		fi
	fi

	setpatchfile ${PATCH_ID}

	if [ "" == "${PATCH_FILE}" ]; then
		echo "Unable to determine patch file for ${PATCH_ID}"
		return 1
	fi

	if [ -f ${LIFERAY_HOME}/patching-tool/patches/${PATCH_FILE} ]; then
		echo "Using existing patch file ${PATCH_FILE}"
		return 0
	fi

	if [ ! -f ${LIFERAY_HOME}/patching-tool/.uptodate ]; then
		cd "${LIFERAY_HOME}"
		rm -rf patching-tool
		getpatchingtool
		cd -

		cd "${LIFERAY_HOME}/patching-tool"
		rm -f default.properties

		mv ../tomcat /tmp
		./patching-tool.sh default auto-discovery ..
		mv /tmp/tomcat ..

		touch .uptodate
		cd -
	fi

	if [ "" != "$PATCH_ID" ]; then
		cd "${LIFERAY_HOME}"
		mkdir -p patches
		getpatch $PATCH_ID
		cd -
	fi

	if [ -d "/build/patches" ]; then
		mkdir -p "${LIFERAY_HOME}/patches"
		rsync -av "/build/patches/" "${LIFERAY_HOME}/patches/"
	fi

	if [ -d "${LIFERAY_HOME}/patches" ]; then
		rsync -av "/${LIFERAY_HOME}/patches/" "${LIFERAY_HOME}/patching-tool/patches/"
	fi

	cd "${LIFERAY_HOME}/patching-tool"
	echo 'auto.update.plugins=true' >> default.properties
	./patching-tool.sh install
	cd -
}

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

downloadbranch() {
	SHORT_NAME=$(echo $BASE_BRANCH | sed 's/ee-//g' | tr -d '.')
	NEW_BASELINE=

	if [ "" != "$PATCH_ID" ] || [ "" != "$RELEASE_ID" ] || [ -d "${LIFERAY_HOME}/patches" ]; then
		downloadreleasebuild
		return 0
	fi

	echo "Trying build server"
	downloadbranchbuild

	if [ "" == "$NEW_BASELINE" ]; then
		echo "Trying mirror server"
		downloadbranchmirror
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

	if [[ "$BASE_BRANCH" == *-private ]]; then
		if [ "" == "$LIFERAY_FILES_MIRROR" ]; then
			return 0
		fi

		REQUEST_URL="$LIFERAY_FILES_MIRROR/private/ee/portal/nightly-$BASE_BRANCH/"
	else
		if [ "" == "$LIFERAY_RELEASES_MIRROR" ]; then
			return 0
		fi

		REQUEST_URL="$LIFERAY_RELEASES_MIRROR/portal/nightly-$BASE_BRANCH/"
	fi

	echo "Identifying build timestamp via ${REQUEST_URL}"

	local BUILD_TIMESTAMP=$(curl -s --connect-timeout 2 $REQUEST_URL | grep -o '<a href="[0-9]*/">' | cut -d'"' -f 2 | sort | tail -1)

	if [ "" == "$BUILD_TIMESTAMP" ]; then
		if [[ "$BASE_BRANCH" == ee-* ]] || [[ "$BASE_BRANCH" == *-private ]]; then
			echo "Unable to identify build timestamp (maybe you forgot to connect to a VPN)"
			return 0
		fi

		LIFERAY_RELEASES_MIRROR=https://releases.liferay.com
		REQUEST_URL="$LIFERAY_RELEASES_MIRROR/portal/nightly-$BASE_BRANCH/"

		echo "Identifying build timestamp via ${REQUEST_URL}"

		BUILD_TIMESTAMP=$(curl -s --connect-timeout 2 $REQUEST_URL | grep -o '<a href="[0-9]*/">' | cut -d'"' -f 2 | sort | tail -1)

		if [ "" == "$BUILD_TIMESTAMP" ]; then
			return 0
		fi
	fi

	REQUEST_URL="${REQUEST_URL}${BUILD_TIMESTAMP}"
	BUILD_TIMESTAMP=$(echo $BUILD_TIMESTAMP | cut -d'/' -f 1)
	BUILD_NAME="$SHORT_NAME-$BUILD_TIMESTAMP.zip"

	echo "Identifying build candidate (branch) via ${REQUEST_URL}"

	local BUILD_CANDIDATE=$(curl -s --connect-timeout 2 $REQUEST_URL | grep -o '<a href="[^"]*tomcat-7.0-[^"]*">' | cut -d'"' -f 2 | sort | tail -1)

	if [ "" == "$BUILD_CANDIDATE" ]; then
		return 0
	fi

	echo $BUILD_CANDIDATE

	REQUEST_URL="${REQUEST_URL}${BUILD_CANDIDATE}"

	NEW_BASELINE=$(echo $BUILD_CANDIDATE | grep -o "[a-z0-9]*.zip" | cut -d'.' -f 1 | cut -d'-' -f 2)

	echo "Downloading snapshot for $SHORT_NAME ($NEW_BASELINE)"

	getbuild $REQUEST_URL $SHORT_NAME-$BUILD_TIMESTAMP.zip
}

downloadbuild() {
	if [ -d /build ] && [ "" != "$(find /build -name catalina.sh)" ]; then
		rsync -arq --exclude=tomcat /build/ ${LIFERAY_HOME}/
		return 0
	elif [ "" != "$(find /opt/liferay -name catalina.sh)" ]; then
		return 0
	elif [ "" != "$BUILD_NAME" ]; then
		cp /build/$BUILD_NAME /opt/liferay
		extract
		return $?
	elif [ "" != "$BASE_TAG" ]; then
		downloadtag && extract
		return $?
	elif [ "" != "$BASE_BRANCH" ]; then
		downloadbranch && extract
		return $?
	else
		echo "Unable to identify base branch"
		return 1
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

	if [[ 10 -ge $(echo "$RELEASE_ID" | cut -d'.' -f 3 | cut -d'-' -f 1) ]]; then
		local RELEASE_ID_NUMERIC=$(echo "$RELEASE_ID" | cut -d'.' -f 1,2,3 | tr -d '.')
		local LICENSE_URL="${LICENSE_MIRROR}/${RELEASE_ID_NUMERIC}.xml"

		echo "Downloading developer license from ${LICENSE_URL}"

		mkdir -p ${LIFERAY_HOME}/deploy/
		curl --connect-timeout 2 -o ${LIFERAY_HOME}/deploy/license.xml "${LICENSE_URL}"

		REQUEST_URL="$LIFERAY_FILES_MIRROR/private/ee/portal/${RELEASE_ID}/"
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

downloadtag() {
	NEW_BASELINE=$BASE_TAG
	BUILD_NAME=${BASE_TAG}.tar.gz

	echo "Downloading snapshot for $BASE_TAG"
	getbuild "${TAG_ARCHIVE_MIRROR}/${BUILD_NAME}"
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

getbuild() {
	local LOCAL_NAME=$(basename $1)

	if [ "" != "$2" ]; then
		LOCAL_NAME=$2
	fi

	if [ -f "${LIFERAY_HOME}/${LOCAL_NAME}" ]; then
		echo "Already downloaded ${LOCAL_NAME}"
		return 0
	fi

	if [ -f "/build/${LOCAL_NAME}" ]; then
		cp "/build/${LOCAL_NAME}" "${LIFERAY_HOME}/${LOCAL_NAME}"
		echo "Already downloaded ${LOCAL_NAME}"
		return 0
	fi

	echo "Attempting to download $1 to ${LOCAL_NAME}"

	curl -o ${LIFERAY_HOME}/${LOCAL_NAME} "$1"
}

getpatch() {
	setpatchfile $1

	if [ "" == "$PATCH_FILE" ]; then
		echo "Unable to determine patch file for $1"
		return 0
	fi

	if [ -f patches/${PATCH_FILE} ]; then
		echo "Using existing patch file ${PATCH_FILE}"
		return 0
	fi

	if [ -f patches/${PATCH_FILE} ]; then
		return 0
	fi

	local RELEASE_ID_SHORT=$(echo "$RELEASE_ID" | cut -d'.' -f 1,2,3)
	local REQUEST_URL="$LIFERAY_FILES_MIRROR/private/ee/fix-packs/${RELEASE_ID_SHORT}/${PATCH_FOLDER}/${PATCH_FILE}"

	echo "Attempting to download ${REQUEST_URL}"
	curl -o patches/${PATCH_FILE} "${REQUEST_URL}"

	if [[ "$PATCH_FILE" == liferay-hotfix-*-7010.zip ]]; then
		local NEEDED_DE_VERSION=$(unzip -c patches/${PATCH_FILE} fixpack_documentation.xml | grep requirements | grep -o 'de=[0-9]*' | cut -d'=' -f 2)

		if [ "" != "${NEEDED_DE_VERSION}" ]; then
			getpatch de-${NEEDED_DE_VERSION}
		else
			echo 'Unable to determine needed DE release from fixpack_documentation.xml'
		fi
	fi
}

getpatchingtool() {
	local REQUEST_URL=${LIFERAY_FILES_MIRROR}/private/ee/fix-packs/patching-tool/

	echo "Checking for latest patching tool at ${REQUEST_URL}"
	local PATCHING_TOOL_VERSION=

	if [[ "$RELEASE_ID" == 7.0.10* ]]; then
		PATCHING_TOOL_VERSION=$(curl $REQUEST_URL | grep -o '<a href="patching-tool-2\.[^"]*' | cut -d'"' -f 2 | grep -F internal | sort | tail -1)
	else
		PATCHING_TOOL_VERSION=$(curl $REQUEST_URL | grep -o '<a href="patching-tool-1\.[^"]*' | cut -d'"' -f 2 | grep -F internal | sort | tail -1)
	fi

	if [ -f $PATCHING_TOOL_VERSION ]; then
		return 0
	fi

	REQUEST_URL=${REQUEST_URL}${PATCHING_TOOL_VERSION}

	echo "Retrieving latest patching tool at ${REQUEST_URL}"
	curl -o $PATCHING_TOOL_VERSION $REQUEST_URL

	rm -rf patching-tool
	unzip $PATCHING_TOOL_VERSION
}

makesymlink() {
	if [ -h ${LIFERAY_HOME}/tomcat ]; then
		return 0
	fi

	CATALINA_HOME=$(find ${LIFERAY_HOME} -mindepth 1 -maxdepth 1 -name 'tomcat*')
	echo "Adding symbolic link to $CATALINA_HOME"
	ln -s $CATALINA_HOME ${LIFERAY_HOME}/tomcat
}

parsearg() {
	if [ "" == "$1" ]; then
		return 0
	fi

	if [ "" != "${BUILD_NAME}" ] || [ "" != "${BASE_TAG}" ]; then
		return 0
	fi

	if [ "" != "${BASE_BRANCH}" ] && [ "master" != "${BASE_BRANCH}" ]; then
		return 0
	fi

	if [ "" != "${BRANCH_ARCHIVE_MIRROR}" ]; then
		SHORT_NAME=$(echo $1 | sed 's/ee-//g' | tr -d '.')
		IS_BRANCH=$(curl -s --connect-timeout 2 $BRANCH_ARCHIVE_MIRROR/ | grep -o '<a href="'${SHORT_NAME}'-[0-9]*.tar.gz">' | cut -d'"' -f 2 | sort | tail -1)

		if [ "" != "${IS_BRANCH}" ]; then
			BASE_BRANCH=${SHORT_NAME}
			return 0
		fi
	fi

	if [[ "$1" == *.x ]] || [ "$1" == "master" ]; then
		BASE_BRANCH=$1
		return 0
	fi

	if [[ "$1" == 7.0.10.* ]] || [[ "$1" == 6.2.10.* ]]; then
		RELEASE_ID=$1
		return 0
	fi

	BASE_TAG=$(curl -s --connect-timeout 2 $TAG_ARCHIVE_MIRROR/tags-ce.txt | grep -F "$1")

	if [ "" != "${BASE_TAG}" ] && [[ 1 == $(echo -n "${BASE_TAG}" | grep -c '^') ]]; then
		return 0
	fi

	BASE_TAG=

	if [[ $1 == http* ]]; then
		PATCH_ID=$(echo $1 | rev | cut -d'/' -f 1 | rev | cut -d'.' -f 1)
	else
		PATCH_ID=$1
	fi
}

setpatchfile() {
	PATCH_FOLDER=
	PATCH_FILE=

	if [[ "$1" == hotfix-*-6210 ]]; then
		PATCH_FOLDER=hotfix
		PATCH_FILE=liferay-$1.zip
	elif [[ "$1" == hotfix-*-7010 ]]; then
		PATCH_FOLDER=hotfix
		PATCH_FILE=liferay-$1.zip
	elif [[ "$1" == hotfix-* ]]; then
		PATCH_FOLDER=hotfix
		PATCH_FILE=liferay-$1-7010.zip
	elif [[ "$1" == liferay-fix-pack-portal-* ]]; then
		PATCH_FOLDER=portal

		if [[ "$1" == *.zip ]]; then
			PATCH_FILE=$1
		else
			PATCH_FILE=$1.zip
		fi
	elif [[ "$1" == portal-* ]]; then
		PATCH_FOLDER=portal

		if [[ "$1" == *-6210.zip ]]; then
			PATCH_FILE=liferay-fix-pack-$1
		elif [[ "$1" == *-6210 ]]; then
			PATCH_FILE=liferay-fix-pack-$1.zip
		else
			PATCH_FILE=liferay-fix-pack-$1-6210.zip
		fi
	elif [[ "$1" == de-* ]]; then
		PATCH_FOLDER=de
		PATCH_FILE=liferay-fix-pack-$1-7010.zip
	elif [[ "$1" == liferay-fix-pack-* ]]; then
		PATCH_FOLDER=de

		if [[ "$1" == *.zip ]]; then
			PATCH_FILE=$1
		else
			PATCH_FILE=$1.zip
		fi
	elif [[ "$1" == liferay-hotfix-* ]]; then
		PATCH_FOLDER=hotfix

		if [[ "$1" == *.zip ]]; then
			PATCH_FILE=$1
		else
			PATCH_FILE=$1.zip
		fi
	fi
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

	sed -n '/ port="8443"/,/-->/p' ${CATALINA_HOME}/conf/server.xml | sed '$d' | sed '$d' >> ${CATALINA_HOME}/conf/server.xml.https
	echo 'keystoreFile="'${LIFERAY_HOME}'/keystore" keystorePass="changeit"' >> ${CATALINA_HOME}/conf/server.xml.https
	sed -n '/ port="8443"/,/-->/p' ${CATALINA_HOME}/conf/server.xml | tail -2 | head -1 >> ${CATALINA_HOME}/conf/server.xml.https
	echo "<!--" >> ${CATALINA_HOME}/conf/server.xml.https

	sed -n '/ port="8443"/,$p' ${CATALINA_HOME}/conf/server.xml >> ${CATALINA_HOME}/conf/server.xml.https

	mv ${CATALINA_HOME}/conf/server.xml ${CATALINA_HOME}/conf/server.xml.http

	cp -f ${CATALINA_HOME}/conf/server.xml.https ${CATALINA_HOME}/conf/server.xml
}

setup_wizard() {
	if [ -f ${HOME}/portal-setup-wizard.properties ] || [ -f ${LIFERAY_HOME}/portal-setup-wizard.properties ]; then
		return 0
	fi

	if [ -f ${LIFERAY_HOME}/portal-ext.properties ] && [ "" != "$(grep -F setup.wizard.enabled ${LIFERAY_HOME}/portal-ext.properties)" ]; then
		return 0
	fi

	local RELEASE_INFO_JAR=${LIFERAY_HOME}/tomcat/lib/ext/portal-kernel.jar

	if [ ! -f ${RELEASE_INFO_JAR} ]; then
		RELEASE_INFO_JAR=${LIFERAY_HOME}/tomcat/lib/ext/portal-service.jar
	fi

	local LP_VERSION=$(groovy -classpath ${RELEASE_INFO_JAR} -e 'print com.liferay.portal.kernel.util.ReleaseInfo.getVersion()')
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

tcp_cluster() {
	if [ "true" != "${IS_CLUSTER}" ]; then
		return 0
	fi

	if [ "" == "$(grep -F cluster.link.enabled= ${HOME}/portal-setup-wizard.properties)" ]; then
		echo '' >> ${HOME}/portal-setup-wizard.properties
		echo 'cluster.link.enabled=true' >> ${HOME}/portal-setup-wizard.properties
		echo "cluster.link.channel.properties.control=${LIFERAY_HOME}/tcp.xml" >> ${HOME}/portal-setup-wizard.properties
		echo "cluster.link.channel.properties.transport.0=${LIFERAY_HOME}/tcp.xml" >> ${HOME}/portal-setup-wizard.properties
	fi

	if [ -f "${LIFERAY_HOME}/tcp.xml" ] && [ ! -f "${LIFERAY_HOME}/tcp.xml.tcpping" ]; then
		echo "Using provided tcp.xml"
		return 0
	fi

	cd ${LIFERAY_HOME}

	if [ -f tcp.xml.tcpping ]; then
		echo "Using already extracted tcp.xml"
		rm -f tcp.xml tcp.xml.jdbcping
		mv tcp.xml.tcpping tcp.xml
	elif [ -d 'osgi/marketplace/Liferay Foundation.lpkg' ]; then
		echo "Extracting tcp.xml from Liferay Foundation.lpkg"
		unzip -qq -j "osgi/marketplace/Liferay Foundation.lpkg" 'com.liferay.portal.cluster.multiple*.jar'
		unzip -qq -j com.liferay.portal.cluster.multiple*.jar 'lib/jgroups*'
		rm com.liferay.portal.cluster.multiple*.jar
		unzip -qq -j jgroups*.jar tcp.xml
		rm jgroups*.jar
	elif [ -f osgi/portal/com.liferay.portal.cluster.multiple.jar ]; then
		echo "Extracting tcp.xml from com.liferay.portal.cluster.multiple.jar"
		unzip -qq -j osgi/portal/com.liferay.portal.cluster.multiple.jar 'lib/jgroups*'
		unzip -qq -j jgroups*.jar tcp.xml
		rm jgroups*.jar
	elif [ -f tomcat/webapps/ROOT/WEB-INF/lib/jgroups.jar ]; then
		echo "Extracting tcp.xml from WEB-INF/lib/jgroups.jar"
		unzip -qq -j tomcat/webapps/ROOT/WEB-INF/lib/jgroups.jar tcp.xml
	else
		echo 'Clustering code not available in this release of Liferay'
		return 0
	fi

	cp -f tcp.xml tcp.xml.tcpping

	if [ "" == "$(grep -F jgroups.tcpping.initial_hosts= ${LIFERAY_HOME}/tomcat/bin/setenv.sh)" ]; then
		local BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)
		local INITIAL_HOSTS=$(seq 255 | awk '{ print "'${BASE_IP}'." $1 "[7800],'${BASE_IP}'." $1 "[7801]" }' | tr '\n' ',' | sed 's/,$//g')

		echo '' >> ${LIFERAY_HOME}/tomcat/bin/setenv.sh
		echo 'CATALINA_OPTS="${CATALINA_OPTS} -Djgroups.tcpping.initial_hosts='${INITIAL_HOSTS}'"' >> ${LIFERAY_HOME}/tomcat/bin/setenv.sh
	fi

	if [ -f ${LIFERAY_HOME}/portal-ext.properties ] && [ "" != "$(grep -F jdbc/LiferayPool ${LIFERAY_HOME}/portal-ext.properties | grep -vF '#')" ]; then
		echo "Replacing TCPPING with JDBC_PING"

		sed -n '1,/<TCPPING/p' tcp.xml | sed '$d' > tcp.xml.jdbcping
		echo '<JDBC_PING datasource_jndi_name="java:comp/env/jdbc/LiferayPool" />' >> tcp.xml.jdbcping
		sed -n '/<MERGE/,$p' tcp.xml >> tcp.xml.jdbcping

		cp -f tcp.xml.jdbcping tcp.xml
	fi

	cd -
}

# Set a random password

if [ "" == "${LIFERAY_PASSWORD}" ]; then
	LIFERAY_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 30 | head -n 1)
fi

# Download and unzip the build

parsearg $1
checkservicepack
downloadbuild
makesymlink
copyextras
setup_wizard

if [ -d /build ]; then
	rsync -arq --exclude=tomcat /build/ ${LIFERAY_HOME}/

	if [ -d /build/tomcat ] && [ "" == "$(find /build/tomcat -name catalina.sh)" ]; then
		rsync -arq /build/tomcat/ ${LIFERAY_HOME}/tomcat/
	fi
fi

if [ -d /opt/ibm/java ]; then
	rm -f /opt/liferay/tomcat/webapps/ROOT/WEB-INF/classes/META-INF/MANIFEST.MF
fi

computername

create_keystore
setup_ssl

tcp_cluster