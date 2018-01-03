#!/bin/bash

# Install Blade CLI

chmod u+x LiferayWorkspace-installer.run
echo -e '2\n\n\n' | ./LiferayWorkspace-installer.run

export PATH="/root/jpm/bin:$PATH"

# Create a Blade workspace

mkdir LPS-76299
blade init LPS-76299

# Navigate to the modules folder

cd LPS-76299/modules

# Create a service builder module

blade create -t service-builder -p com.example.mismatch example-schema-mismatch

# Build the sample services project

blade gw :modules:example-schema-mismatch:example-schema-mismatch-service:buildService

# Create a simple portlet project named example-schema-mismatch-web

blade create -t mvc-portlet -p com.example.mismatch.web example-schema-mismatch-web

# Update the build.gradle for example-schema-mismatch-web to contain a dependency on the example-schema-mismatch-api

sed -i.bak 's/}/\tcompileOnly project(":modules:example-schema-mismatch:example-schema-mismatch-api")\n}/g' example-schema-mismatch-web/build.gradle

# Update src/main/java/com/example/mismatch/web/portlet/ExampleSchemaMismatchPortlet.java in example-schema-mismatch-web so that it contains a reference to the service from example-schema-mismatch-api:

portlet_file='example-schema-mismatch-web/src/main/java/com/example/mismatch/web/portlet/ExampleSchemaMismatchWebPortlet.java'

mv ${portlet_file} ${portlet_file}.old

head -n 1 ${portlet_file}.old > ${portlet_file}
echo -e '\nimport org.osgi.service.component.annotations.Reference;\nimport com.example.mismatch.service.FooLocalService;' >> ${portlet_file}
tail -n +2 ${portlet_file}.old | sed '$d' >> ${portlet_file}
echo -n -e '\t@Reference\n\tprivate FooLocalService _fooLocalService;\n}' >> ${portlet_file}

# Build all the modules once

blade gw :modules:example-schema-mismatch:example-schema-mismatch-api:deploy \
	:modules:example-schema-mismatch:example-schema-mismatch-service:compileJava \
	:modules:example-schema-mismatch-web:deploy