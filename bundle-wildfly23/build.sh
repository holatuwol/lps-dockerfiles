#!/bin/bash

if [ "" == "${IMAGE_NAME}" ]; then
	IMAGE_NAME=liferay
fi

if [ "" == "${DOCKERHUB_USER}" ]; then
	DOCKERHUB_USER=holatuwol
fi

docker build . -t "${DOCKERHUB_USER}/${IMAGE_NAME}:$(basename $PWD | sed 's/^bundle-//g')"

if [ "push" == "$1" ]; then
	docker push "${DOCKERHUB_USER}/${IMAGE_NAME}:$(basename $PWD | sed 's/^bundle-//g')"
fi