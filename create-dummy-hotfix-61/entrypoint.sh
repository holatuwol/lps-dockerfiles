#!/bin/bash

if [ ! -d /source ]; then
  echo 'docker run --rm -v ${PORTAL_SOURCE}:/source holatuwol/create-dummy-hotfix:6120'
  exit 1
fi

cd /source

echo "app.server.parent.dir=/bundles
app.server.tomcat.version=${TOMCAT_VERSION}
" | tee app.server.${HOSTNAME}.properties

echo "ant.build.javac.source=1.6
ant.build.javac.target=1.6

app.server.dir=/bundles/tomcat-${TOMCAT_VERSION}
" | tee /plugins/build.${HOSTNAME}.properties

cp /apache-tomcat-${TOMCAT_VERSION}.zip /bundles/

export PATH="/miniconda3/bin:/opt/java/ant/bin:${PATH}"

rm -rf /patch/*

ant clean && \
 ant -f build-dist.xml unzip-tomcat && \
 ant start deploy && \
  rm app.server.${HOSTNAME}.properties && \
  /scripts/create_ext_plugin.sh && \
  python -u /scripts/fixed_issues.py && \
  /scripts/prepare_hotfix.sh && \
  python -u /scripts/create_fp_docs.py