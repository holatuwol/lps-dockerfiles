#!/bin/bash

cp -f ../nightly/bundle.sh .
cp -f ../nightly/common.sh .
cp -f ../nightly/entrypoint.sh .
cp -f ../nightly/upgrade.sh .

IMAGE_NAME=$1

if [ "" == "${IMAGE_NAME}" ]; then
	IMAGE_NAME=mcd-nightly-jdk7
fi

docker build . -t "${IMAGE_NAME}"