#!/bin/bash

downloadbranch() {
	SHORT_NAME=$(echo $BASE_BRANCH | sed 's/ee-//g' | tr -d '.')
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