#!/bin/bash

IMAGE_NAME=$1

if [ "" == "${IMAGE_NAME}" ]; then
	IMAGE_NAME=liferay-elasticsearch:6.0
fi

docker build . -t "${IMAGE_NAME}"