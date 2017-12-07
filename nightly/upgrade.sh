#!/bin/bash

echo "Starting upgrade..."

cd ${LIFERAY_HOME}/tools/portal-tools-db-upgrade-client/
java -jar com.liferay.portal.tools.db.upgrade.client.jar -j "-Dfile.encoding=UTF8 -Duser.timezone=GMT -Xmx8g"