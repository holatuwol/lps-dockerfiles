#!/bin/bash

CATALINA_OPTS="${CATALINA_OPTS} -Dfile.encoding=UTF-8 -Djava.net.preferIPv4Stack=true -Duser.timezone=GMT -Xms${JVM_HEAP_SIZE} -Xmx${JVM_HEAP_SIZE} -XX:PermSize=1g -XX:MaxPermSize=1g"