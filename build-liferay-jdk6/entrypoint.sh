#!/bin/bash

if [ ! -d /source ]; then
  echo 'docker run --rm -v ${PORTAL_SOURCE}:/source -v ${LIFERAY_HOME}:/bundles holatuwol/build-liferay:jdk6'
  exit 1
fi

if [ ! -d /bundles ]; then
  echo 'docker run --rm -v ${PORTAL_SOURCE}:/source -v ${LIFERAY_HOME}:/bundles holatuwol/build-liferay:jdk6'
  exit 1
fi

cd /source

rm -f app.server.${HOSTNAME}.properties

echo "app.server.parent.dir=/bundles
app.server.tomcat.version=7.0.109
" | tee app.server.${HOSTNAME}.properties

cp /apache-tomcat-${TOMCAT_VERSION}.zip /bundles/

/opt/java/ant/bin/ant clean && \
  /opt/java/ant/bin/ant -f build-dist.xml unzip-tomcat && \
  /opt/java/ant/bin/ant start deploy