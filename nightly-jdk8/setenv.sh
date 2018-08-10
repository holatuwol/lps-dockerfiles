#!/bin/bash

if [ "" == "${JVM_HEAP_SIZE}" ]; then
  JVM_HEAP_SIZE='2g'
fi

CATALINA_OPTS="${CATALINA_OPTS} -Dfile.encoding=UTF-8 -Djava.net.preferIPv4Stack=true -Duser.timezone=GMT -Xms${JVM_HEAP_SIZE} -Xmx${JVM_HEAP_SIZE} -XX:MaxMetaspaceSize=1g -XX:MetaspaceSize=1g"