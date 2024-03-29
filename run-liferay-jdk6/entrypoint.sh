#!/bin/bash

cd /

if [ -f liferay-portal-tomcat-6.1.10-*.zip ]; then
	rm -rf liferay-portal-6.1.10-*
	unzip -qq liferay-portal-tomcat-6.1.10-*.zip
	cd liferay-portal-6.1.10-*
elif [ -f liferay-portal-tomcat-6.1.20-*.zip ]; then
	rm -rf liferay-portal-6.1.20-*
	unzip -qq liferay-portal-tomcat-6.1.20-*.zip
	cd liferay-portal-6.1.20-*
fi

if [ "" != "$(find ../patches -name 'patching-tool*.zip')" ]; then
	rm -rf patching-tool
	unzip -qq ../patches/patching-tool*.zip
fi

test -d /patches && cp /patches/*.zip patching-tool/patches/
sed -i 's@PT_OPTS=@echo PT_OPTS=@g' patching-tool/patching-tool.sh
cd patching-tool

chmod u+x patching-tool.sh
./patching-tool.sh auto-discovery
./patching-tool.sh install

mkdir -p ../deploy
cp /license.xml ../deploy/

if [ -f /portal-setup-wizard.properties ]; then
	cp /portal-setup-wizard.properties ../
else
	echo -n 'setup.wizard.enabled=false' > ../portal-setup-wizard.properties
fi

cd ../tomcat*/bin

if [ -f /web.xml ]; then
	cp /web.xml ../webapps/ROOT/WEB-INF/
fi

./catalina.sh jpda run