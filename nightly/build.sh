#!/bin/bash

APP_SERVER_SCRIPT=$(grep -F app_ .gitignore)

cp -f ../nightly/${APP_SERVER_SCRIPT} .

if [ "app_tomcat.sh" == "${APP_SERVER_SCRIPT}" ]; then
	cp -f ../nightly/enable_ajp.py .
fi

cp -f ../nightly/bundle.sh .
cp -f ../nightly/cluster.sh .
cp -f ../nightly/common.sh .
cp -f ../nightly/download_branch.sh .
cp -f ../nightly/download_build.sh .
cp -f ../nightly/download_release.sh .
cp -f ../nightly/entrypoint.sh .
cp -f ../nightly/install_jar.sh .
cp -f ../nightly/setenv.sh .
cp -f ../nightly/upgrade.sh .
cp -f ../nightly/sslconfig.cnf.base .

if [ "" == "${IMAGE_NAME}" ]; then
	IMAGE_NAME=liferay
fi

if [ "" == "${DOCKERHUB_USER}" ]; then
	DOCKERHUB_USER=holatuwol
fi

docker build . -t "${DOCKERHUB_USER}/${IMAGE_NAME}:$(basename $PWD | sed 's/^nightly-//g')"

if [ "push" == "$1" ]; then
	docker push "${DOCKERHUB_USER}/${IMAGE_NAME}:$(basename $PWD | sed 's/^nightly-//g')"
fi