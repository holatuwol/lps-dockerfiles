#!/bin/bash

if [ ! -d /source ]; then
  echo 'docker run --rm -v ${PORTAL_SOURCE}:/source holatuwol/create-dummy-hotfix:6110'
  exit 1
fi

if [ -f /jdk-8u301-linux-x64.tar.gz ]; then
	echo 'Extracting /jdk-8u301-linux-x64.tar.gz'
	cd /
	tar -zxf /jdk-8u301-linux-x64.tar.gz
	export JAVA_HOME=/jdk1.8.0_301
	export PATH="/jdk1.8.0_301/bin:${PATH}"
elif [ -f /jdk-8u202-linux-x64.tar.gz ]; then
	echo 'Extracting /jdk-8u202-linux-x64.tar.gz'
	cd /
	tar -zxf /jdk-8u202-linux-x64.tar.gz
	export JAVA_HOME=/jdk1.8.0_202
	export PATH="/jdk1.8.0_202/bin:${PATH}"
fi

cd /source

echo "app.server.parent.dir=/bundles
app.server.tomcat.version=${TOMCAT_VERSION}
" | tee app.server.${HOSTNAME}.properties

echo "ant.build.javac.source=1.6
ant.build.javac.target=1.6
javac.compiler=modern

app.server.dir=/bundles/tomcat-${TOMCAT_VERSION}
" | tee /plugins/build.${HOSTNAME}.properties

cp /apache-tomcat-${TOMCAT_VERSION}.zip /bundles/

export PATH="/miniconda3/bin:/opt/java/ant/bin:${PATH}"

rm -rf /patch/*

ant clean && \
 ant -f build-dist.xml unzip-tomcat && \
 ant start deploy && \
  rm app.server.${HOSTNAME}.properties && \
  JAVA_HOME="${JAVA_HOME}" PATH="${PATH}" /scripts/create_ext_plugin.sh && \
  python -u /scripts/fixed_issues.py && \
  JAVA_HOME="${JAVA_HOME}" PATH="${PATH}" /scripts/prepare_hotfix.sh && \
  python -u /scripts/create_fp_docs.py