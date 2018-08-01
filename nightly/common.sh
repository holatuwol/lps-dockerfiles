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
	SERVICE_PACKS[de-40]=7.0.10.7
	SERVICE_PACKS[de-50]=7.0.10.8

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

	if [[ "${1}" == *-7110 ]]; then
		RELEASE_ID=7.1.10
		return 0
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

copyextras() {
	if [ -d "/build/drivers" ]; then
		local GLOBAL_LIB=$(dirname $(find ${LIFERAY_HOME} -name portlet.jar))

		if [ -f /usr/bin/rsync ]; then
			rsync -aq "/build/drivers/" "${GLOBAL_LIB}"
		else
			cp -f "/build/drivers/*" "${GLOBAL_LIB}"
		fi
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

		if [ -h ../tomcat ]; then
			mv ../tomcat /tmp
			./patching-tool.sh default auto-discovery ..
			mv /tmp/tomcat ..
		else
			./patching-tool.sh default auto-discovery ..
		fi

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

		if [ -f /usr/bin/rsync ]; then
			rsync -av "/build/patches/" "${LIFERAY_HOME}/patches/"
		else
			cp -f /build/patches/ "${LIFERAY_HOME}/patches/"
		fi
	fi

	if [ -d "${LIFERAY_HOME}/patches" ]; then
		if [ -f /usr/bin/rsync ]; then
			rsync -av "/${LIFERAY_HOME}/patches/" "${LIFERAY_HOME}/patching-tool/patches/"
		else
			cp -f /${LIFERAY_HOME}/patches/* "${LIFERAY_HOME}/patching-tool/patches/"
		fi
	fi

	cd "${LIFERAY_HOME}/patching-tool"
	echo 'auto.update.plugins=true' >> default.properties
	./patching-tool.sh install
	cd -
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

downloadbuild() {
	if [ "false" == "${DOWNLOAD_BUILD}" ]; then
		return 0
	elif [ -d /build ] && [ "" != "$(find /build -name catalina.sh)" ]; then
		rsync -arq --exclude=tomcat /build/ ${LIFERAY_HOME}/

		return 0
	elif [ "" != "$(find ${LIFERAY_HOME} -name catalina.sh)" ]; then
		return 0
	elif [ "" != "$BUILD_NAME" ]; then
		cp /build/$BUILD_NAME ${LIFERAY_HOME}
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

downloadlicense() {
	local RELEASE_ID_NUMERIC=$(echo "$RELEASE_ID" | cut -d'.' -f 1,2,3 | tr -d '.')
	local LICENSE_URL="${LICENSE_MIRROR}/${RELEASE_ID_NUMERIC}.xml"

	echo "Downloading developer license from ${LICENSE_URL}"

	mkdir -p ${LIFERAY_HOME}/deploy/
	curl --connect-timeout 2 -o ${LIFERAY_HOME}/deploy/license.xml "${LICENSE_URL}"

	REQUEST_URL="$LIFERAY_FILES_MIRROR/private/ee/portal/${RELEASE_ID}/"
}

downloadtag() {
	NEW_BASELINE=$BASE_TAG
	BUILD_NAME=${BASE_TAG}.tar.gz

	echo "Downloading snapshot for $BASE_TAG"
	getbuild "${TAG_ARCHIVE_MIRROR}/${BUILD_NAME}"
}

envreload() {
	if [ -f ${HOME}/.oldenv ]; then
		source ${HOME}/.oldenv

		return 0
	fi

	# Set a random password

	if [ "" == "${LIFERAY_PASSWORD}" ]; then
		LIFERAY_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 30 | head -n 1)
	fi

	# Download and unzip the build

	parsearg $1
	checkservicepack
	downloadbuild

	env | grep -v '^PWD=' > ${HOME}/.oldenv
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
		if [ "" != "$1" ]; then
			echo "Unable to determine patch file for $1"
		fi

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

	if [[ "$1" == 7.1.* ]] || [[ "$1" == 7.0.* ]] || [[ "$1" == 6.2.* ]] || [[ "$1" == 6.1.* ]]; then
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

	if [[ "$1" == hotfix-*-6210 ]] || [[ "$1" == hotfix-*-7010 ]] || [[ "$1" == hotfix-*-7110 ]]; then
		PATCH_FOLDER=hotfix
		PATCH_FILE=liferay-$1.zip
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
	elif [ -f "${LIFERAY_HOME}/osgi/marketplace/Liferay Foundation.lpkg" ]; then
		echo "Extracting tcp.xml from Liferay Foundation.lpkg"
		unzip -qq -j "${LIFERAY_HOME}/osgi/marketplace/Liferay Foundation.lpkg" 'com.liferay.portal.cluster.multiple*.jar'
		unzip -qq -j com.liferay.portal.cluster.multiple*.jar 'lib/jgroups*'
		rm com.liferay.portal.cluster.multiple*.jar
		unzip -qq -j jgroups*.jar tcp.xml
		rm jgroups*.jar
	elif [ -f ${LIFERAY_HOME}/osgi/portal/com.liferay.portal.cluster.multiple.jar ]; then
		echo "Extracting tcp.xml from com.liferay.portal.cluster.multiple.jar"
		unzip -qq -j ${LIFERAY_HOME}/osgi/portal/com.liferay.portal.cluster.multiple.jar 'lib/jgroups*'
		unzip -qq -j jgroups*.jar tcp.xml
		rm jgroups*.jar
	else
		JGROUPS_JAR=$(find ${LIFERAY_HOME} -name 'jgroups.jar' | grep -F '/WEB-INF/lib/jgroups.jar')

		if [ "" != "${JGROUPS_JAR}" ]; then
			echo "Extracting tcp.xml from WEB-INF/lib/jgroups.jar"
			unzip -qq -j tomcat/webapps/ROOT/WEB-INF/lib/jgroups.jar tcp.xml
		else
			echo 'Clustering code not available in this release of Liferay'
			return 0
		fi
	fi

	cp -f tcp.xml tcp.xml.tcpping

	if [ -f tcp.xml.jdbcping ] && [ "" != "$(grep -F jdbc.default ${LIFERAY_HOME}/portal-ext.properties | grep -vF '#')" ]; then
		sed -n '1,/<TCPPING/p' tcp.xml | sed '$d' > tcp.xml.jdbcping

		local JNDI_NAME=$(grep -F jdbc.default.jndi.name= ${LIFERAY_HOME}/portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
		local DRIVER_CLASS_NAME=$(grep -F jdbc.default.driverClassName= ${LIFERAY_HOME}/portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
		local DRIVER_URL=$(grep -F jdbc.default.url= ${LIFERAY_HOME}/portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
		local USERNAME=$(grep -F jdbc.default.username= ${LIFERAY_HOME}/portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
		local PASSWORD=$(grep -F jdbc.default.password= ${LIFERAY_HOME}/portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)

		if [ "" != "${JNDI_NAME}" ]; then
			echo "Replacing TCPPING with JDBC_PING (JNDI)"
			echo '<JDBC_PING datasource_jndi_name="java:comp/env/'${JNDI_NAME}'" />' >> tcp.xml.jdbcping
		else
			echo "Replacing TCPPING with JDBC_PING (${DRIVER_URL})"
			echo '<JDBC_PING connection_url="'$(echo ${DRIVER_URL} | sed 's/&/&amp;/g')'" connection_username="'${USERNAME}'" connection_password="'${PASSWORD}'" connection_driver="'${DRIVER_CLASS_NAME}'" />' >> tcp.xml.jdbcping
		fi

		sed -n '/<MERGE/,$p' tcp.xml >> tcp.xml.jdbcping

		cp -f tcp.xml.jdbcping tcp.xml
	fi

	cd -
}