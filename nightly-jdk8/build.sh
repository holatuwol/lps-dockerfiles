#!/bin/bash

cp -f ../nightly/bundle.sh .
cp -f ../nightly/common.sh .
cp -f ../nightly/entrypoint.sh .
cp -f ../nightly/upgrade.sh .

docker build . -t mcd-nightly-jdk8