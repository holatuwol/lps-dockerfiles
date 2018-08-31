#!/bin/bash

cp -f ../nightly/app_tomcat.sh .
cp -f ../nightly/bundle.sh .
cp -f ../nightly/common.sh .
cp -f ../nightly/entrypoint.sh .
cp -f ../nightly/upgrade.sh .
cp -f ../nightly/sslconfig.cnf.base .

IMAGE_NAME=$1
DOCKERHUB_USER=$2

if [ "" == "${IMAGE_NAME}" ]; then
	IMAGE_NAME=liferay
fi

if [ "" == "${DOCKERHUB_USER}" ]; then
	DOCKERHUB_USER=holatuwol
fi

docker build . -t "${DOCKERHUB_USER}/${IMAGE_NAME}:$(basename $PWD | sed 's/^nightly-//g')"
docker push "${DOCKERHUB_USER}/${IMAGE_NAME}:$(basename $PWD | sed 's/^nightly-//g')"