#!/bin/bash

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
		. ${HOME}/download_build.sh
		downloadtag && extract && install
		return $?
	elif [ "" != "$PATCH_ID" ] || [ "" != "$RELEASE_ID" ] || [ -d "${LIFERAY_HOME}/patches" ]; then
		. ${HOME}/download_release.sh
		downloadrelease && extract && install
		return $?
	elif [ "" != "$BASE_BRANCH" ]; then
		. ${HOME}/download_build.sh
		downloadbranch && extract && install
		return $?
	else
		echo "Unable to identify base branch"
		return 1
	fi
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
	downloadbuild

	echo 'Saving environment variables'
	env | grep -v '^\(OLD\)*PWD=' | grep -v '=$' | tee ${HOME}/.oldenv
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

javahome() {
	if [ "" != "${JAVA_HOME}" ]; then
		return 0
	fi

	if [ -d /usr/lib/jvm/ ]; then
		JAVA_HOME=/usr/lib/jvm/$(ls -1 /usr/lib/jvm/ | tail -1)
	fi
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

	BASE_TAG=$(curl -s --connect-timeout 2 $TAG_ARCHIVE_MIRROR/tags.txt | grep "^$1$")

	if [ "" != "${BASE_TAG}" ] && [[ 1 == $(echo -n "${BASE_TAG}" | grep -c '^') ]]; then
		return 0
	fi

	BASE_TAG=$(curl -s --connect-timeout 2 $TAG_ARCHIVE_MIRROR/tags-ce.txt | grep "^$1$")

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

javahome