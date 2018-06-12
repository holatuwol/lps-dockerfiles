#!/bin/bash

echo "Starting Liferay"

if [ "" == "${JVM_HEAP_SIZE}" ]; then
	JVM_HEAP_SIZE='2g'
fi

sed -i.bak "s/-Xms[^ ]*/-Xms${JVM_HEAP_SIZE}/g" ${LIFERAY_HOME}/tomcat/bin/setenv.sh
sed -i.bak "s/-Xmx[^ ]*/-Xmx${JVM_HEAP_SIZE}/g" ${LIFERAY_HOME}/tomcat/bin/setenv.sh

JPDA_ADDRESS='0.0.0.0:8000' ${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run