#!/bin/bash

if [ -f /opt/jboss/tcp.xml ] && [ "" != "$(grep -F TCPPING /opt/jboss/tcp.xml)" ]; then
  BASE_IP=$(hostname -I | cut -d'.' -f 1,2,3)
  INITIAL_HOSTS=$(seq 255 | awk '{ print "'${BASE_IP}'." $1 "[7800],'${BASE_IP}'." $1 "[7801]" }' | tr '\n' ',' | sed 's/,$//g')
  CATALINA_OPTS="${CATALINA_OPTS} -Djgroups.tcpping.initial_hosts='${INITIAL_HOSTS}'"
fi

CATALINA_OPTS="${CATALINA_OPTS} -Dfile.encoding=UTF-8 -Djava.net.preferIPv4Stack=true -Duser.timezone=GMT -Xms${JVM_HEAP_SIZE} -Xmx${JVM_HEAP_SIZE} -XX:MaxMetaspaceSize=1g -XX:MetaspaceSize=1g"