#!/bin/bash


downloadbranch() {
	SHORT_NAME=$(echo $BASE_BRANCH | sed 's/ee-//g' | sed 's/\.//g')
	NEW_BASELINE=

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

	if [[ "$BASE_BRANCH" == ee-* ]] || [[ "$BASE_BRANCH" == *-private ]]; then
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

	echo "Attempting to download from ${REQUEST_URL}"

	local BUILD_TIMESTAMP=$(curl -s --connect-timeout 2 $REQUEST_URL | grep -o '<a href="[0-9]*/">' | cut -d'"' -f 2 | sort | tail -1)

	if [ "" == "$BUILD_TIMESTAMP" ]; then
		if [[ "$BASE_BRANCH" == ee-* ]] || [[ "$BASE_BRANCH" == *-private ]]; then
			return 0
		fi

		LIFERAY_RELEASES_MIRROR=https://releases.liferay.com
		REQUEST_URL="$LIFERAY_RELEASES_MIRROR/portal/nightly-$BASE_BRANCH/"
		BUILD_TIMESTAMP=$(curl -s --connect-timeout 2 $REQUEST_URL | grep -o '<a href="[0-9]*/">' | cut -d'"' -f 2 | sort | tail -1)

		if [ "" == "$BUILD_TIMESTAMP" ]; then
			return 0
		fi
	fi

	REQUEST_URL="${REQUEST_URL}${BUILD_TIMESTAMP}"
	BUILD_TIMESTAMP=$(echo $BUILD_TIMESTAMP | cut -d'/' -f 1)
	BUILD_NAME="$SHORT_NAME-$BUILD_TIMESTAMP.zip"

	local BUILD_CANDIDATE=$(curl -s --connect-timeout 2 $REQUEST_URL | grep -o '<a href="[^"]*tomcat-7.0-[^"]*">' | cut -d'"' -f 2 | sort | tail -1)

	if [ "" == "$BUILD_TIMESTAMP" ]; then
		return 0
	fi

	REQUEST_URL="${REQUEST_URL}${BUILD_CANDIDATE}"

	NEW_BASELINE=$(echo $BUILD_CANDIDATE | grep -o "[a-z0-9]*.zip" | cut -d'.' -f 1 | cut -d'-' -f 2)

	echo "Downloading snapshot for $SHORT_NAME ($NEW_BASELINE)"

	getbuild $REQUEST_URL $SHORT_NAME-$BUILD_TIMESTAMP.zip
}

downloadbuild() {
	if [ -h ${LIFERAY_HOME}/tomcat ]; then
		return 0
	fi

	if [ -d /build ] && [ "" != "$(find "${LIFERAY_HOME}" -name catalina.sh)" ]; then
		return 0
	elif [ "" != "$BUILD_NAME" ]; then
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

	if [[ "$BUILD_NAME" == *.tar.gz ]]; then
		tar -zxf ${BUILD_NAME}
	elif [[ "$BUILD_NAME" == *.zip ]]; then
		unzip -qq "${BUILD_NAME}"
	fi

	local TOMCAT_NAME=$(find . -mindepth 1 -maxdepth 1 -type d -name 'tomcat*')

	if [ "" == "$TOMCAT_NAME" ]; then
		local UNZIP_NAME=$(find . -mindepth 1 -maxdepth 1 -type d)

		echo "Unzipping $UNZIP_NAME"

		for file in $(find $UNZIP_NAME -mindepth 1 -maxdepth 1); do
			mv $file .
		done

		rmdir $UNZIP_NAME
	fi

	rm $BUILD_NAME

	cd -
}

getbuild() {
	local LOCAL_NAME=$(basename $1)

	if [ "" != "$2" ]; then
		LOCAL_NAME=$2
	fi

	echo "Attempting to download from $1"

	curl -o ${LIFERAY_HOME}/${LOCAL_NAME} "$1"
}

makesymlink() {
	if [ -h ${LIFERAY_HOME}/tomcat ]; then
		return 0
	fi

	CATALINA_HOME=$(find ${LIFERAY_HOME} -mindepth 1 -maxdepth 1 -name 'tomcat*')
	ls -1 ${LIFERAY_HOME}
	echo "Adding symbolic link to $CATALINA_HOME"
	ln -s $CATALINA_HOME ${LIFERAY_HOME}/tomcat
}

# Download and unzip the build

if [ -d /build ]; then
	rsync -avr /build/ ${LIFERAY_HOME}/
fi

downloadbuild
makesymlink

# Copy portal-ext.properties, if present

# Run the build

echo "Starting Liferay"
${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run