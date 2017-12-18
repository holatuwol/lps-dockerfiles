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

	if [ "" != "${SERVICE_PACKS[${PATCH_ID}]}" ]; then
		RELEASE_ID=${SERVICE_PACKS[${PATCH_ID}]}
		PATCH_ID=
	elif [[ "${PATCH_ID}" == *-7010 ]]; then
		RELEASE_ID=7.0.10
	elif [[ "${PATCH_ID}" == *-6210 ]]; then
		RELEASE_ID=6.2.10
	fi
}

copyextras() {
	if [ -d "/build/drivers" ]; then
		rsync -av "/build/drivers/" "${LIFERAY_HOME}/tomcat/lib/ext/"
	fi

	if [ "" == "$RELEASE_ID" ] || [[ 10 -lt $(echo "$RELEASE_ID" | cut -d'.' -f 3 | cut -d'-' -f 1) ]]; then
		echo "Not an EE release, so patches will not be installed"
		return 0
	fi

	if [ ! -f ${LIFERAY_HOME}/patching-tool/default.properties ]; then
		cd "${LIFERAY_HOME}"
		getpatchingtool
		cd -

		cd "${LIFERAY_HOME}/patching-tool"
		./patching-tool.sh auto-discovery .. | grep -F '=' | tee default.properties
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

downloadbranch() {
	SHORT_NAME=$(echo $BASE_BRANCH | sed 's/ee-//g' | sed 's/\.//g')
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
	if [ "" != "$(find /opt/liferay -name catalina.sh)" ]; then
		return 0
	fi

	if [ -d /build ] && [ "" != "$(find /build -name catalina.sh)" ]; then
		rsync -avrq --exclude=tomcat /build/ ${LIFERAY_HOME}/
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
				mv $file .
			done

			rmdir $OLD_LIFERAY_HOME
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
	local PATCH_FOLDER=
	local PATCH_FILE=

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

	if [ "" == "$PATCH_FILE" ]; then
		echo "Unable to determine patch file from $1"
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

	if [[ "$1" == *.x ]] || [ "$1" == "master" ]; then
		BASE_BRANCH=$1
		return 0
	fi

	if [[ "$1" == fix-pack-* ]]; then
		BASE_TAG=$1
		return 0
	fi

	if [[ "$1" == 7.0.10* ]] || [[ "$1" == 6.2.10* ]]; then
		RELEASE_ID=$1
		return 0
	fi

	PATCH_ID=$1
}

# Download and unzip the build

parsearg $1
checkservicepack
downloadbuild
makesymlink
copyextras

if [ -d /build ] && [ "" == "$(find /build -name catalina.sh)" ]; then
	rsync -avrq --exclude=tomcat /build/ ${LIFERAY_HOME}/

	if [ -d /build/tomcat ]; then
		rsync -avrq /build/tomcat/ ${LIFERAY_HOME}/tomcat/
	fi
fi
