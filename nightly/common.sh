#!/bin/bash

checkservicepack() {
	if [ "" != "${RELEASE_ID}" ]; then
		echo "Already identified release as ${RELEASE_ID}"
		return 0
	fi

	if [ "" == "${PATCH_ID}" ]; then
		return 0
	fi

	if [[ ${PATCH_ID} == *hotfix* ]]; then
		if [[ ${PATCH_ID} == *-7010 ]] || [[ ${PATCH_ID} == *-7010.zip ]]; then
			RELEASE_ID=7.0.10
		elif [[ ${PATCH_ID} == *-7110 ]] || [[ ${PATCH_ID} == *-7110.zip ]]; then
			RELEASE_ID=7.1.10
		fi

		cd "${LIFERAY_HOME}"
		mkdir -p patches
		getpatch ${PATCH_ID}
		cd -

		RELEASE_ID=
	fi

	if [ "" == "${PATCH_ID}" ]; then
		return 0
	fi

	echo "Checking service pack for ${PATCH_ID}"

	declare -A SERVICE_PACKS

	SERVICE_PACKS[portal-0]=6.2.10
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

	SERVICE_PACKS[de-0]=7.0.10
	SERVICE_PACKS[de-7]=7.0.10.1
	SERVICE_PACKS[de-12]=7.0.10.2
	SERVICE_PACKS[de-14]=7.0.10.3
	SERVICE_PACKS[de-22]=7.0.10.4
	SERVICE_PACKS[de-30]=7.0.10.5
	SERVICE_PACKS[de-32]=7.0.10.6
	SERVICE_PACKS[de-40]=7.0.10.7
	SERVICE_PACKS[de-50]=7.0.10.8
	SERVICE_PACKS[de-60]=7.0.10.9

	SERVICE_PACKS[dxp-0]=7.1.10

	closestservicepack ${PATCH_ID}
}

closestservicepack() {
	RELEASE_ID=${SERVICE_PACKS[${1}]}

	if [ "" != "${RELEASE_ID}" ]; then
		echo "Exactly matches service pack ${RELEASE_ID}"
		return 0
	fi

	if [[ "${1}" == portal-* ]]; then
		for id in $(seq 0 $(echo "${1}" | cut -d'-' -f 2) | tac); do
			RELEASE_ID=${SERVICE_PACKS[portal-${id}]}

			if [ "" != "${RELEASE_ID}" ]; then
				echo "${1} is closest to service pack ${RELEASE_ID}"
				return 0
			fi
		done
	fi

	if [[ "${1}" == de-* ]]; then
		for id in $(seq 0 $(echo "${1}" | cut -d'-' -f 2) | tac); do
			RELEASE_ID=${SERVICE_PACKS[de-${id}]}

			if [ "" != "${RELEASE_ID}" ]; then
				echo "${1} is closest to service pack ${RELEASE_ID}"
				return 0
			fi
		done
	fi

	if [[ "${1}" == dxp-* ]]; then
		for id in $(seq 0 $(echo "${1}" | cut -d'-' -f 2) | tac); do
			RELEASE_ID=${SERVICE_PACKS[dxp-${id}]}

			if [ "" != "${RELEASE_ID}" ]; then
				echo "${1} is closest to service pack ${RELEASE_ID}"
				return 0
			fi
		done
	fi

	if [[ "${1}" == *-7110 ]]; then
		RELEASE_ID=7.1.10
		echo "Failed to guess the service pack for ${1}, assuming ${RELEASE_ID}"
		return 0
	fi

	if [[ "${1}" == *-7010 ]]; then
		RELEASE_ID=7.0.10
		echo "Failed to guess the service pack for ${1}, assuming ${RELEASE_ID}"
		return 0
	fi

	if [[ "${1}" == *-6210 ]]; then
		RELEASE_ID=6.2.10
		echo "Failed to guess the service pack for ${1}, assuming ${RELEASE_ID}"
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

	local UP_TO_DATE=false

	if [ -d ${LIFERAY_HOME}/patches ]; then
		UP_TO_DATE=true

		for file in ${LIFERAY_HOME}/patches/*; do
			if [ ! -f ${LIFERAY_HOME}/patching-tool/patches/${file} ]; then
				UP_TO_DATE=false
			fi
		done
	fi

	if [ "false" == "${UP_TO_DATE}" ]; then
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
		rsync -arq --exclude=tomcat --exclude=logs /build/ ${LIFERAY_HOME}/

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
	if [ -d /build/deploy ] && [ "" != "$(find /build/deploy -name '*.xml')" ]; then
		return 0
	fi

	if [ -d ${LIFERAY_HOME}/deploy ] && [ "" != "$(find ${LIFERAY_HOME}/deploy -name '*.xml')" ]; then
		return 0
	fi

	if [ -d /build/data/license ] || [ -d ${LIFERAY_HOME}/data/license ]; then
		return 0
	fi

	local RELEASE_ID_NUMERIC=$(echo "$RELEASE_ID" | cut -d'.' -f 1,2,3 | tr -d '.')
	local LICENSE_URL="${LICENSE_MIRROR}/${RELEASE_ID_NUMERIC}.xml"

	echo "Downloading developer license from ${LICENSE_URL}"

	mkdir -p ${LIFERAY_HOME}/deploy/
	curl --connect-timeout 2 -o ${LIFERAY_HOME}/deploy/license.xml "${LICENSE_URL}"

	REQUEST_URL="$LIFERAY_FILES_MIRROR/private/ee/portal/${RELEASE_ID}/"
}

envreload() {
	if [ -f ${HOME}/.oldenv ]; then
		echo 'Loading old environment variables'
		cat ${HOME}/.oldenv

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

	echo 'Saving environment variables'
	env | grep -v '^\(OLD\)*PWD=' | grep -v '=$' | tee ${HOME}/.oldenv
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

	local PATCH_LOCATION="patches/${PATCH_FILE}"

	if [ -f ${LIFERAY_HOME}/patches/${PATCH_FILE} ]; then
		PATCH_LOCATION="${LIFERAY_HOME}/patches/${PATCH_FILE}"
		echo "Using existing patch file ${PATCH_LOCATION}"
	elif [ -f ${LIFERAY_HOME}/patching-tool/patches/${PATCH_FILE} ]; then
		PATCH_LOCATION="${LIFERAY_HOME}/patching-tool/patches/${PATCH_FILE}"
		echo "Using existing patch file ${PATCH_LOCATION}"
	elif [ -f /build/patches/${PATCH_FILE} ]; then
		PATCH_LOCATION="/build/patches/${PATCH_FILE}"
		echo "Using existing patch file ${PATCH_LOCATION}"
	else
		local RELEASE_ID_SHORT=$(echo "$RELEASE_ID" | cut -d'.' -f 1,2,3)
		local REQUEST_URL="$LIFERAY_FILES_MIRROR/private/ee/fix-packs/${RELEASE_ID_SHORT}/${PATCH_FOLDER}/${PATCH_FILE}"

		echo "Attempting to download ${REQUEST_URL}"
		curl -o ${PATCH_LOCATION} "${REQUEST_URL}"
	fi

	local NEEDED_PATCH_ID=

	if [[ "${PATCH_FILE}" == liferay-hotfix-*-7010.zip ]]; then
		PATCH_ID=
		NEEDED_PATCH_ID=$(unzip -c ${PATCH_LOCATION} fixpack_documentation.xml | grep requirements | grep -o 'de=[0-9]*' | cut -d'=' -f 2)

		if [ "" != "${NEEDED_PATCH_ID}" ]; then
			PATCH_ID=de-${NEEDED_PATCH_ID}
		fi
	elif [[ "${PATCH_FILE}" == liferay-hotfix-*-7110.zip ]]; then
		PATCH_ID=
		NEEDED_PATCH_ID=$(unzip -c ${PATCH_LOCATION} fixpack_documentation.xml | grep requirements | grep -o 'dxp=[0-9]*' | cut -d'=' -f 2)

		if [ "" != "${NEEDED_PATCH_ID}" ]; then
			PATCH_ID=dxp-${NEEDED_PATCH_ID}
		fi
	fi
}

getpatchingtool() {
	local REQUEST_URL=${LIFERAY_FILES_MIRROR}/private/ee/fix-packs/patching-tool/

	echo "Checking for latest patching tool at ${REQUEST_URL}"
	local PATCHING_TOOL_VERSION=

	if [[ "$RELEASE_ID" == 6.2.10* ]]; then
		PATCHING_TOOL_VERSION=patching-tool-$(curl $REQUEST_URL/LATEST.txt)-internal.zip
	else
		PATCHING_TOOL_VERSION=patching-tool-$(curl $REQUEST_URL/LATEST-2.0.txt)-internal.zip
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

	if [[ "$1" == *.x ]] || [[ "$1" == *.x-private ]] || [ "$1" == "master" ] || [ "$1" == "master-private" ]; then
		BASE_BRANCH=$1
		return 0
	fi

	if [[ "$1" == *x ]] || [[ "$1" == *x-private ]]; then
		BASE_BRANCH=$(echo $1 | sed 's/^\([0-9]*\)\([0-9]\)x/\1.\2.x/')
		return 0
	fi

	if [ "" != "$(echo $1 | grep -o '^[0-9]*\.[0-9]*')" ]; then
		RELEASE_ID=$1
		return 0
	fi

	if [ "" != "$(echo $1 | grep -o '^[0-9]*$')" ]; then
		RELEASE_ID=$(echo $1 | sed 's/^\([0-9]*\)\([0-9]\)\([0-9][0-9]\)$/\1.\2.\3/')
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

	if [[ "$1" == hotfix-* ]]; then
		PATCH_FOLDER=hotfix
		PATCH_FILE=liferay-$1.zip
	elif [[ "$1" == liferay-hotfix-* ]]; then
		PATCH_FOLDER=hotfix

		if [[ "$1" == *.zip ]]; then
			PATCH_FILE=$1
		else
			PATCH_FILE=$1.zip
		fi
	elif [[ "$1" == liferay-fix-pack-portal-* ]]; then
		PATCH_FOLDER=portal

		if [[ "$1" == *.zip ]]; then
			PATCH_FILE=$1
		else
			PATCH_FILE=$1.zip
		fi
	elif [[ "$1" == liferay-fix-pack-de-* ]]; then
		PATCH_FOLDER=de

		if [[ "$1" == *.zip ]]; then
			PATCH_FILE=$1
		else
			PATCH_FILE=$1.zip
		fi
	elif [[ "$1" == liferay-fix-pack-dxp-* ]]; then
		PATCH_FOLDER=dxp

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
	elif [[ "$1" == dxp-* ]]; then
		PATCH_FOLDER=dxp
		PATCH_FILE=liferay-fix-pack-$1-7110.zip
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

	if [ ! -f ${LIFERAY_HOME}/tcp.xml ]; then
		pushd ${LIFERAY_HOME} > /dev/null
		tcp_extractxml
		popd > /dev/null
	fi

	if [ ! -f ${LIFERAY_HOME}/tcp.xml ]; then
		echo 'Unable to extract tcp.xml'
		return 1
	fi

	if [ ! -f portal-ext.properties ] || [ "" == "$(grep -F jdbc.default portal-ext.properties | grep -vF '#')" ]; then
		echo 'No database properties set, cluster will be limited to one node'
		return 0
	fi

	pushd ${LIFERAY_HOME} > /dev/null
	tcp_jdbcping
	popd > /dev/null
}

tcp_extractxml() {
	if [ "" == "$(grep -F cluster.link.enabled= ${HOME}/portal-setup-wizard.properties)" ]; then
		echo '' >> ${HOME}/portal-setup-wizard.properties
		echo 'cluster.link.enabled=true' >> ${HOME}/portal-setup-wizard.properties
		echo "cluster.link.channel.properties.control=${LIFERAY_HOME}/tcp.xml" >> ${HOME}/portal-setup-wizard.properties
		echo "cluster.link.channel.properties.transport.0=${LIFERAY_HOME}/tcp.xml" >> ${HOME}/portal-setup-wizard.properties
	fi

	if [ -f ${LIFERAY_HOME}/osgi/portal/com.liferay.portal.cluster.multiple.jar ]; then
		echo "Extracting tcp.xml from com.liferay.portal.cluster.multiple.jar"
		unzip -qq -j ${LIFERAY_HOME}/osgi/portal/com.liferay.portal.cluster.multiple.jar 'lib/jgroups*'
		unzip -qq -j jgroups*.jar tcp.xml
		rm jgroups*.jar

		return 0
	fi

	if [ ! -d ${LIFERAY_HOME}/osgi/marketplace ]; then
		return 1
	fi

	while read -r lpkg; do
		if [ "" == "$(unzip -l "${lpkg}" | grep -F 'com.liferay.portal.cluster.multiple')" ]; then
			continue
		fi

		echo "Extracting tcp.xml from ${lpkg}"
		unzip -qq -j "${lpkg}" 'com.liferay.portal.cluster.multiple*.jar'
		unzip -qq -j com.liferay.portal.cluster.multiple*.jar 'lib/jgroups*'
		rm com.liferay.portal.cluster.multiple*.jar
		unzip -qq -j jgroups*.jar tcp.xml
		rm jgroups*.jar

		return 0
	done <<< "$(find ${LIFERAY_HOME}/osgi/marketplace -name '*.lpkg')"

	JGROUPS_JAR=$(find ${LIFERAY_HOME} -name 'jgroups.jar' | grep -F '/WEB-INF/lib/jgroups.jar')

	if [ "" != "${JGROUPS_JAR}" ]; then
		echo "Extracting tcp.xml from WEB-INF/lib/jgroups.jar"
		unzip -qq -j tomcat/webapps/ROOT/WEB-INF/lib/jgroups.jar tcp.xml
		return 0
	fi

	return 1
}

tcp_jdbcping() {
	echo "Using JDBC_PING for clustering"

	local JNDI_NAME=$(grep -F jdbc.default.jndi.name= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
	local DRIVER_CLASS_NAME=$(grep -F jdbc.default.driverClassName= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
	local DRIVER_URL=$(grep -F jdbc.default.url= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
	local USERNAME=$(grep -F jdbc.default.username= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
	local PASSWORD=$(grep -F jdbc.default.password= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)

	# If using Tomcat, force a switch to JNDI

	if [ "" != "${CATALINA_HOME}" ]; then
		if [ "" == "${JNDI_NAME}" ]; then
			JNDI_NAME='jdbc/LiferayPool'
			echo -e '\njdbc.default.jndi.name=jdbc/LiferayPool' >> portal-ext.properties
		fi

		local ROOT_XML="${CATALINA_HOME}/conf/Catalina/localhost/ROOT.xml"

		if [ -f ${ROOT_XML} ]; then
			mkdir -p $(dirname ${ROOT_XML})
			echo -e '<Context crossContext="true" path="">\n</Context>' > ${ROOT_XML}
		fi

		if [ "" == "$(grep -F "${JNDI_NAME}" ${ROOT_XML})" ]; then
			mv ${ROOT_XML} ${ROOT_XML}.old
			grep -vF '</Context>' ${ROOT_XML}.old > ${ROOT_XML}
			echo '
	<Resource name="'${JNDI_NAME}'"
		auth="Container"
		type="javax.sql.DataSource"
		factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
		driverClassName="'${DRIVER_CLASS_NAME}'"
		url="'$(echo ${DRIVER_URL} | sed 's/&/&amp;/g')'"
		username="'$(echo ${USERNAME} | sed 's/&/&amp;/g')'"
		password="'$(echo ${PASSWORD} | sed 's/&/&amp;/g')'"
		maxActive="20" maxIdle="5" />
</Context>' >> ${ROOT_XML}
		fi
	fi

	# Generate a JDBC connection URL for JGroups

	local CONNECT_OPTIONS=

	if [ "" != "${JNDI_NAME}" ]; then
		CONNECT_OPTIONS='
datasource_jndi_name="java:comp/env/'${JNDI_NAME}'"
'
	else
		CONNECT_OPTIONS='
connection_driver="'${DRIVER_CLASS_NAME}'"
connection_url="'$(echo ${DRIVER_URL} | sed 's/&/&amp;/g')'"
connection_username="'$(echo ${USERNAME} | sed 's/&/&amp;/g')'"
connection_password="'$(echo ${PASSWORD} | sed 's/&/&amp;/g')'"
'
	fi

	# Choose the binary data type

	local BINARY_DATA_TYPE=

	if [ "" == "${DRIVER_CLASS_NAME}" ] || [ "org.hsqldb.jdbc.JDBCDriver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='varbinary(5000)'
	elif [ "org.mariadb.jdbc.Driver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='longblob'
	elif [ "com.mysql.jdbc.Driver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='longblob'
	elif [ "oracle.jdbc.OracleDriver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='blob'
	elif [ "org.postgresql.Driver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='bytea'
	elif [ "com.microsoft.sqlserver.jdbc.SQLServerDriver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='image'
	elif [ "com.sybase.jdbc4.jdbc.SybDriver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='image'
	else
		BINARY_DATA_TYPE='varbinary(5000)'
	fi

	# Use the binary data type to generate the correct create table statement

	local EXTRA_OPTIONS='
initialize_sql="CREATE TABLE JGROUPSPING (own_addr varchar(200) NOT NULL, cluster_name varchar(200) NOT NULL, ping_data '${BINARY_DATA_TYPE}', constraint PK_JGROUPSPING PRIMARY KEY (own_addr, cluster_name))"
'

	# Generate a new tcp.xml with the proper JDBC_PING configuration

	sed -n '1,/<TCPPING/p' tcp.xml | sed '$d' > tcp.xml.jdbcping
	echo "<JDBC_PING ${CONNECT_OPTIONS} ${EXTRA_OPTIONS} />" >> tcp.xml.jdbcping
	sed -n '/<MERGE/,$p' tcp.xml >> tcp.xml.jdbcping

	cp -f tcp.xml.jdbcping tcp.xml
	rm tcp.xml.jdbcping
}