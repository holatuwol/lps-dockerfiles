#!/bin/bash

envreload $1

makesymlink
copyextras

if [ -d /build ]; then
	rsync -arq --exclude=tomcat --exclude=logs /build/ ${LIFERAY_HOME}/

	if [ -d /build/tomcat ] && [ "" == "$(find /build/tomcat -name catalina.sh)" ]; then
		rsync -arq /build/tomcat/ ${LIFERAY_HOME}/tomcat/
	fi
fi

if [ -d /opt/ibm/java ]; then
	rm -f /opt/liferay/tomcat/webapps/ROOT/WEB-INF/classes/META-INF/MANIFEST.MF
fi

# Execute the upgrade

echo "Starting upgrade..."

if [ "" == "${JVM_HEAP_SIZE}" ]; then
	JVM_HEAP_SIZE='8g'
fi

mkdir -p ${LIFERAY_HOME}/osgi/configs
echo 'indexReadOnly=true' > ${LIFERAY_HOME}/osgi/configs/com.liferay.portal.search.configuration.IndexStatusManagerConfiguration.cfg

touch ${LIFERAY_HOME}/.liferay-home

echo "dir=${LIFERAY_HOME}/tomcat
extra.lib.dirs=/bin
global.lib.dir=/lib
portal.dir=/webapps/ROOT
server.detector.server.id=tomcat" > ${LIFERAY_HOME}/tools/portal-tools-db-upgrade-client/app-server.properties

cat ${LIFERAY_HOME}/tools/portal-tools-db-upgrade-client/app-server.properties

grep -F 'jdbc.default' ${LIFERAY_HOME}/portal-ext.properties > ${LIFERAY_HOME}/tools/portal-tools-db-upgrade-client/portal-upgrade-database.properties
grep -vF 'jdbc.default' ${LIFERAY_HOME}/portal-ext.properties | grep . > ${LIFERAY_HOME}/tools/portal-tools-db-upgrade-client/portal-upgrade-ext.properties
echo "liferay.home=${LIFERAY_HOME}" >> ${LIFERAY_HOME}/tools/portal-tools-db-upgrade-client/portal-upgrade-ext.properties

cd ${LIFERAY_HOME}/tools/portal-tools-db-upgrade-client/

if [ -f db_upgrade.sh ]; then
	./db_upgrade.sh -j "-Dfile.encoding=UTF8 -Duser.timezone=GMT -Xmx${JVM_HEAP_SIZE}"
else
	java -Duser.dir=$PWD -jar com.liferay.portal.tools.db.upgrade.client.jar -j "-Dfile.encoding=UTF8 -Duser.timezone=GMT -Xmx${JVM_HEAP_SIZE}"
fi