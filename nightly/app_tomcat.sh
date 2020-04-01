#!/bin/bash

create_keystore() {
	if [ -f ${LIFERAY_HOME}/keystore ]; then
		return 0
	fi

	if [ -f /build/keystore ]; then
		cp /build/keystore ${LIFERAY_HOME}/
		return 0
	fi

	local BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)
	local COPY_KEYSTORE=

	if [ -f /build/server.crt ] && [ -f /build/server.key ]; then
		COPY_KEYSTORE=/build/server.crt

		cp /build/server.crt ${LIFERAY_HOME}/
		cp /build/server.key ${LIFERAY_HOME}/
	else
		cp /home/liferay/sslconfig.cnf.base ${LIFERAY_HOME}/sslconfig.cnf
		echo '' >> ${LIFERAY_HOME}/sslconfig.cnf

		seq 255 | awk '{ print "IP." $1 " = '${BASE_IP}'." $1 }' >> ${LIFERAY_HOME}/sslconfig.cnf
		echo "IP.256 = 127.0.0.1" >> ${LIFERAY_HOME}/sslconfig.cnf

		echo | openssl req -config ${LIFERAY_HOME}/sslconfig.cnf -new -sha256 -newkey rsa:2048 \
			-nodes -keyout ${LIFERAY_HOME}/server.key -x509 -days 365 \
			-out ${LIFERAY_HOME}/server.crt
	fi

	openssl pkcs12 -export \
		-in ${LIFERAY_HOME}/server.crt -inkey ${LIFERAY_HOME}/server.key -passin pass:'' \
		-out ${LIFERAY_HOME}/server.p12 -passout pass:'' -name tomcat

	keytool -importkeystore -destkeypass changeit \
		-deststorepass changeit -destkeystore ${LIFERAY_HOME}/keystore \
		-srckeystore ${LIFERAY_HOME}/server.p12 -srcstorepass '' -srcstoretype PKCS12 -alias tomcat

	if [ -d /build/ ] && [ "" == "${COPY_KEYSTORE}" ]; then
		cp -f ${LIFERAY_HOME}/server.crt /build/
		cp -f ${LIFERAY_HOME}/server.key /build/
		cp -f ${LIFERAY_HOME}/keystore /build/
	fi
}

prepare_server() {
	if [ ! -f ${CATALINA_HOME}/bin/setenv.sh ]; then
		cp -f ${HOME}/setenv.sh ${CATALINA_HOME}/bin/
	elif [ "" == "$(grep -F "${HOME}/setenv.sh" ${CATALINA_HOME}/bin/setenv.sh)" ]; then
		echo -e "\n\n. ${HOME}/setenv.sh" >> ${CATALINA_HOME}/bin/setenv.sh
	fi

	python /home/liferay/enable_ajp.py ${CATALINA_HOME}/conf/server.xml

	if [ -d /opt/ibm/java ]; then
		return 0
	fi

	create_keystore

	if [ -f ${CATALINA_HOME}/cacerts ]; then
		return 0
	fi

	cp ${JAVA_HOME}/jre/lib/security/cacerts ${CATALINA_HOME}/
	keytool -import -noprompt -keystore ${CATALINA_HOME}/cacerts -storepass changeit -file ${LIFERAY_HOME}/server.crt -alias client

	if [ -f ${CATALINA_HOME}/conf/server.xml.http ]; then
		rm -f ${CATALINA_HOME}/conf/server.xml ${CATALINA_HOME}/conf/server.xml.https
		mv ${CATALINA_HOME}/conf/server.xml.http ${CATALINA_HOME}/conf/server.xml
	fi

	sed -n '1,/ port="8443"/p' ${CATALINA_HOME}/conf/server.xml | sed '$d' | sed '$d' > ${CATALINA_HOME}/conf/server.xml.https

	if [ "" != "$(grep -F 'Apache Tomcat Version 9' ${CATALINA_HOME}/RELEASE-NOTES)" ]; then
		sed -n '/ port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"/,/<Certificate/p' ${CATALINA_HOME}/conf/server.xml | sed '$d' >> ${CATALINA_HOME}/conf/server.xml.https
		echo '<Certificate certificateKeystoreFile="'${LIFERAY_HOME}'/keystore" type="RSA" />' >> ${CATALINA_HOME}/conf/server.xml.https
		echo '</SSLHostConfig>' >> ${CATALINA_HOME}/conf/server.xml.https
		echo '</Connector>' >> ${CATALINA_HOME}/conf/server.xml.https
	else
		sed -n '/ port="8443"/,/-->/p' ${CATALINA_HOME}/conf/server.xml | sed '$d' | sed '$d' >> ${CATALINA_HOME}/conf/server.xml.https
		echo 'keystoreFile="'${LIFERAY_HOME}'/keystore" keystorePass="changeit"' >> ${CATALINA_HOME}/conf/server.xml.https
		sed -n '/ port="8443"/,/-->/p' ${CATALINA_HOME}/conf/server.xml | tail -2 | head -1 >> ${CATALINA_HOME}/conf/server.xml.https
	fi

	echo '<!--' >> ${CATALINA_HOME}/conf/server.xml.https
	sed -n '/ port="8443"/,$p' ${CATALINA_HOME}/conf/server.xml >> ${CATALINA_HOME}/conf/server.xml.https

	mv ${CATALINA_HOME}/conf/server.xml ${CATALINA_HOME}/conf/server.xml.http

	cp -f ${CATALINA_HOME}/conf/server.xml.https ${CATALINA_HOME}/conf/server.xml
}

start_server() {
	sed -i.bak 's/-Xms[^ \"]*/-Xms'${JVM_HEAP_SIZE}'/g' ${LIFERAY_HOME}/tomcat/bin/setenv.sh
	sed -i.bak 's/-Xmx[^ \"]*/-Xmx'${JVM_HEAP_SIZE}'/g' ${LIFERAY_HOME}/tomcat/bin/setenv.sh

	JVM_HEAP_SIZE="${JVM_HEAP_SIZE}" JPDA_ADDRESS='0.0.0.0:8000' ${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run
}