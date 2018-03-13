#!/bin/bash

cp -f ../nightly/bundle.sh .
cp -f ../nightly/common.sh .
cp -f ../nightly/entrypoint.sh .
cp -f ../nightly/upgrade.sh .
cp -f ../nightly/sslconfig.cnf.base .

IMAGE_NAME=$1

if [ "" == "${IMAGE_NAME}" ]; then
	IMAGE_NAME=mcd-nightly-jdk8
fi

docker build . -t "${IMAGE_NAME}"