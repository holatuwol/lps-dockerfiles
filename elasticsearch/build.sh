#!/bin/bash

IMAGE_NAME=$1

if [ "" == "${IMAGE_NAME}" ]; then
	IMAGE_NAME=liferay-elasticsearch:2.4
fi

docker build . -t "${IMAGE_NAME}"