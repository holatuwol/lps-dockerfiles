#!/bin/bash

if [ ! /bundles/tomcat-${TOMCAT_VERSION}/bin ]; then
  echo 'docker run --rm -v ${LIFERAY_HOME}:/bundles -p 8080:8080 -p 8000:8000 run-liferay:jdk6'
  exit 1
fi

/bundles/tomcat-${TOMCAT_VERSION}/bin/catalina.sh jpda run