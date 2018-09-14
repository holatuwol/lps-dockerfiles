#!/bin/sh

setup_tcp_initial_hosts() {
	CATALINA_OPTS="${CATALINA_OPTS} -Djgroups.bind_addr='$(hostname -I)'"

	if ! test -f ${LIFERAY_HOME}/tcp.xml; then
		return 0
	fi

	if [ "" != "$(grep -F TCPPING ${LIFERAY_HOME}/tcp.xml)" ]; then
		return 0
	fi

	echo 'Adding all potential nodes in network to jgroups.tcpping.initial_hosts'

	BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)
	INITIAL_HOSTS=$(seq 255 | awk '{ print "'${BASE_IP}'." $1 "[7800],'${BASE_IP}'." $1 "[7801]" }' | tr '\n' ',' | sed 's/,$//g')
	CATALINA_OPTS="${CATALINA_OPTS} -Djgroups.tcpping.initial_hosts='${INITIAL_HOSTS}'"
}

. ${HOME}/.oldenv
setup_tcp_initial_hosts

CATALINA_OPTS="${CATALINA_OPTS} -Dfile.encoding=UTF-8 -Djava.net.preferIPv4Stack=true -Duser.timezone=GMT"
CATALINA_OPTS="${CATALINA_OPTS} -Xms${JVM_HEAP_SIZE} -Xmx${JVM_HEAP_SIZE}"
CATALINA_OPTS="${CATALINA_OPTS} -XX:MaxMetaspaceSize=${JVM_META_SIZE} -XX:MaxPermSize=${JVM_META_SIZE}"