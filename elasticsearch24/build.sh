#!/bin/bash

IMAGE_NAME=$1
DOCKERHUB_USER=$2

if [ "" == "${IMAGE_NAME}" ]; then
	IMAGE_NAME=liferay-elasticsearch
fi

if [ "" == "${DOCKERHUB_USER}" ]; then
	DOCKERHUB_USER=holatuwol
fi

docker build . -t "${DOCKERHUB_USER}/${IMAGE_NAME}:2.4"
docker push "${DOCKERHUB_USER}/${IMAGE_NAME}:2.4"