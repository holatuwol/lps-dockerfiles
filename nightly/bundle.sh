#!/bin/bash

envreload $1

makesymlink
copyextras
setup_wizard

if [ -d /build ]; then
	rsync -arq --exclude=tomcat --exclude=logs /build/ ${LIFERAY_HOME}/

	if [ -d /build/tomcat ] && [ "" == "$(find /build/tomcat -name catalina.sh)" ]; then
		rsync -arq /build/tomcat/ ${LIFERAY_HOME}/tomcat/
	fi
fi

if [ -d /opt/ibm/java ]; then
	rm -f /opt/liferay/tomcat/webapps/ROOT/WEB-INF/classes/META-INF/MANIFEST.MF
fi

if [ ! -f ${CATALINA_HOME}/bin/setenv.sh ]; then
	cp -f ${HOME}/setenv.sh ${CATALINA_HOME}/bin/
elif [ "" == "$(grep -F "${HOME}/setenv.sh" ${CATALINA_HOME}/bin/setenv.sh)" ]; then
	echo -e "\n\n. ${HOME}/setenv.sh" >> ${CATALINA_HOME}/bin/setenv.sh
fi

# Setup SSH and clustering

create_keystore
setup_ssl

if [ -f ${LIFERAY_HOME}/portal-ext.properties ]; then
	BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)
	sed -i.bak "s/localhost/${BASE_IP}.1/g" ${LIFERAY_HOME}/portal-ext.properties
fi

# Start Liferay

if [ "" == "${JVM_HEAP_SIZE}" ]; then
	JVM_HEAP_SIZE='2g'
fi

if [ "" == "${JVM_META_SIZE}" ]; then
	JVM_META_SIZE='512m'
fi

tcp_cluster && startserver