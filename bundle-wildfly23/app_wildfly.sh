#!/bin/bash


add_module_xml() {
	mkdir -p ${WILDFLY_HOME}/modules/com/liferay/portal/main/

	echo '<?xml version="1.0"?>
<module xmlns="urn:jboss:module:1.0" name="com.liferay.portal">' > ${WILDFLY_HOME}/modules/com/liferay/portal/main/module.xml

	if [ -d ${CATALINA_HOME}/lib/ext ]; then
	(
		echo '<resources>'

		for file in ccpp.jar hsql.jar portal-kernel.jar portal-service.jar portlet.jar; do
			if [ ! -f "${CATALINA_HOME}/lib/ext/${file}" ]; then
				continue
			fi

			cp ${CATALINA_HOME}/lib/ext/${file} ${WILDFLY_HOME}/modules/com/liferay/portal/main/
			echo '<resource-root path="'${file}'" />'
		done

		for file in ${CATALINA_HOME}/lib/ext/com.liferay.*; do
			cp ${file} ${WILDFLY_HOME}/modules/com/liferay/portal/main/
			echo '<resource-root path="'${file}'" />'
		done

		echo '</resources>'
	) >> ${WILDFLY_HOME}/modules/com/liferay/portal/main/module.xml
	fi

	echo '<dependencies>
<module name="ibm.jdk" />
<module name="javax.api" />
<module name="javax.mail.api" />
<module name="javax.servlet.api" />
<module name="javax.servlet.jsp.api" />
<module name="javax.transaction.api" />
</dependencies>' >> ${WILDFLY_HOME}/modules/com/liferay/portal/main/module.xml

	echo '</module>' >> ${WILDFLY_HOME}/modules/com/liferay/portal/main/module.xml
}

prepare_server() {
	cd ${LIFERAY_HOME}
	CATALINA_HOME="${LIFERAY_HOME}/tomcat"

	mkdir -p ${WILDFLY_HOME}/standalone/deployments/
	ln -s ${CATALINA_HOME}/webapps/ROOT ${WILDFLY_HOME}/standalone/deployments/ROOT.war

	add_module_xml

	if [ -d ${CATALINA_HOME}/lib/ext ]; then
		cp ${LIFERAY_HOME}/osgi/core/com.liferay.osgi.service.tracker.collections*.jar ${WILDFLY_HOME}/modules/com/liferay/portal/main/com.liferay.osgi.service.tracker.collections.jar
	fi

	touch ${WILDFLY_HOME}/standalone/deployments/ROOT.war.dodeploy
}

start_server() {
	sed -i.bak "s/-Xms[0-9MmGg]*/-Xms${JVM_HEAP_SIZE}/g" ${WILDFLY_HOME}/bin/standalone.conf
	sed -i.bak "s/-Xmx[0-9MmGg]*/-Xmx${JVM_HEAP_SIZE}/g" ${WILDFLY_HOME}/bin/standalone.conf
	sed -i.bak "s/-XX:MetaspaceSize=[0-9MmGg]*//g" ${WILDFLY_HOME}/bin/standalone.conf
	sed -i.bak "s/-XX:MaxMetaspaceSize=[0-9MmGg]*//g" ${WILDFLY_HOME}/bin/standalone.conf

	if [ "" == "$(grep -F file.encoding ${WILDFLY_HOME}/bin/standalone.conf)" ]; then
		echo '
JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8 -Djava.locale.providers=JRE,COMPAT,CLDR -Djava.net.preferIPv4Stack=true -Dlog4j2.formatMsgNoLookups=true -Duser.timezone=GMT"
' >> ${WILDFLY_HOME}/bin/standalone.conf
	fi

	/opt/jboss/wildfly/bin/standalone.sh -b 0.0.0.0 --debug '*:8000'
}