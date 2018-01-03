#!/bin/bash

export PATH="/root/jpm/bin:$PATH"

# Navigate to the modules folder

cd LPS-76299/modules

# Update the bnd.bnd with the specified version

BUNDLE_VERSION=$1

if [ "" == "${BUNDLE_VERSION}" ]; then
	BUNDLE_VERSION=1.0.0
fi

bnd_file='example-schema-mismatch/example-schema-mismatch-service/bnd.bnd'

sed -i.bak "s/Bundle-Version: .*$/Bundle-Version: ${BUNDLE_VERSION}/g" ${bnd_file}
sed -i.bak "s/Liferay-Require-SchemaVersion: .*$/Liferay-Require-SchemaVersion: ${BUNDLE_VERSION}/g" ${bnd_file}

# Deploy the jars for the example-schema-mismatch-service

blade gw :modules:example-schema-mismatch:example-schema-mismatch-service:deploy