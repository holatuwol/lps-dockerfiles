#!/bin/bash

echo "Starting upgrade..."

if [ "" == "${JVM_HEAP_SIZE}" ]; then
	JVM_HEAP_SIZE='8g'
fi

mkdir -p ${LIFERAY_HOME}/osgi/configs
echo 'indexReadOnly=true' > ${LIFERAY_HOME}/osgi/configs/ com.liferay.portal.search.configuration.IndexStatusManagerConfiguration.cfg

cd ${LIFERAY_HOME}/tools/portal-tools-db-upgrade-client/
java -jar com.liferay.portal.tools.db.upgrade.client.jar -j "-Dfile.encoding=UTF8 -Duser.timezone=GMT -Xmx${JVM_HEAP_SIZE}"