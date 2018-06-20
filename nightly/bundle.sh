#!/bin/bash

envreload $1

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

# Setup SSH and clustering

create_keystore
setup_ssl

if [ -f ${LIFERAY_HOME}/portal-ext.properties ]; then
	BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)
	sed -i.bak "s/localhost/${BASE_IP}.1/g" ${LIFERAY_HOME}/portal-ext.properties
fi

tcp_cluster

# Start Liferay

echo "Starting Liferay"

if [ "" == "${JVM_HEAP_SIZE}" ]; then
	JVM_HEAP_SIZE='2g'
fi

sed -i.bak "s/-Xms[^ ]*/-Xms${JVM_HEAP_SIZE}/g" ${LIFERAY_HOME}/tomcat/bin/setenv.sh
sed -i.bak "s/-Xmx[^ ]*/-Xmx${JVM_HEAP_SIZE}/g" ${LIFERAY_HOME}/tomcat/bin/setenv.sh

JPDA_ADDRESS='0.0.0.0:8000' ${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run