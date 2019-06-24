#!/bin/bash

tcp_cluster() {
	if [ "true" != "${IS_CLUSTER}" ]; then
		return 0
	fi

	if [ -f /build/tcp.xml ]; then
		cp /build/tcp.xml ${LIFERAY_HOME}/
		return 0
	fi

	pushd ${LIFERAY_HOME} > /dev/null
	tcp_extractxml
	popd > /dev/null

	if [ ! -f ${LIFERAY_HOME}/tcp.xml ]; then
		echo 'Unable to extract tcp.xml'
		return 1
	fi

	if [ ! -f portal-ext.properties ] || [ "" == "$(grep -F jdbc.default portal-ext.properties | grep -vF '#')" ]; then
		echo 'No database properties set, cluster will be limited to one node'
		return 0
	fi

	pushd ${LIFERAY_HOME} > /dev/null
	tcp_jdbcping
	popd > /dev/null
}

tcp_extractxml() {
	rm -f tcp.xml

	if [ "" == "$(grep -F cluster.link.enabled= ${HOME}/portal-setup-wizard.properties)" ]; then
		echo '' >> ${HOME}/portal-setup-wizard.properties
		echo 'cluster.link.enabled=true' >> ${HOME}/portal-setup-wizard.properties
		echo "cluster.link.channel.properties.control=${LIFERAY_HOME}/tcp.xml" >> ${HOME}/portal-setup-wizard.properties
		echo "cluster.link.channel.properties.transport.0=${LIFERAY_HOME}/tcp.xml" >> ${HOME}/portal-setup-wizard.properties
	fi

	if [ -f ${LIFERAY_HOME}/osgi/portal/com.liferay.portal.cluster.multiple.jar ]; then
		echo "Extracting tcp.xml from com.liferay.portal.cluster.multiple.jar"
		unzip -qq -j ${LIFERAY_HOME}/osgi/portal/com.liferay.portal.cluster.multiple.jar 'lib/jgroups*'
		unzip -qq -j jgroups*.jar tcp.xml
		rm jgroups*.jar

		return 0
	fi

	if [ ! -d ${LIFERAY_HOME}/osgi/marketplace ]; then
		return 1
	fi

	while read -r lpkg; do
		if [ "" == "$(unzip -l "${lpkg}" | grep -F 'com.liferay.portal.cluster.multiple')" ]; then
			continue
		fi

		echo "Extracting tcp.xml from ${lpkg}"
		unzip -qq -j "${lpkg}" 'com.liferay.portal.cluster.multiple*.jar'
		unzip -qq -j com.liferay.portal.cluster.multiple*.jar 'lib/jgroups*'
		rm com.liferay.portal.cluster.multiple*.jar
		unzip -qq -j jgroups*.jar tcp.xml
		rm jgroups*.jar

		return 0
	done <<< "$(find ${LIFERAY_HOME}/osgi/marketplace -name '*.lpkg')"

	JGROUPS_JAR=$(find ${LIFERAY_HOME} -name 'jgroups.jar' | grep -F '/WEB-INF/lib/jgroups.jar')

	if [ "" != "${JGROUPS_JAR}" ]; then
		echo "Extracting tcp.xml from WEB-INF/lib/jgroups.jar"
		unzip -qq -j tomcat/webapps/ROOT/WEB-INF/lib/jgroups.jar tcp.xml
		return 0
	fi

	return 1
}

tcp_jdbcping() {
	echo "Using JDBC_PING for clustering"

	local JNDI_NAME=$(grep -F jdbc.default.jndi.name= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
	local DRIVER_CLASS_NAME=$(grep -F jdbc.default.driverClassName= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
	local DRIVER_URL=$(grep -F jdbc.default.url= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
	local USERNAME=$(grep -F jdbc.default.username= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)
	local PASSWORD=$(grep -F jdbc.default.password= portal-ext.properties | grep -vF '#' | cut -d'=' -f 2-)

	# If using Tomcat, force a switch to JNDI

	if [ "" != "${CATALINA_HOME}" ]; then
		if [ "" == "${JNDI_NAME}" ]; then
			JNDI_NAME='jdbc/LiferayPool'
			echo -e '\njdbc.default.jndi.name=jdbc/LiferayPool' >> portal-ext.properties
		fi

		local ROOT_XML="${CATALINA_HOME}/conf/Catalina/localhost/ROOT.xml"

		if [ -f ${ROOT_XML} ]; then
			mkdir -p $(dirname ${ROOT_XML})
			echo -e '<Context crossContext="true" path="">\n</Context>' > ${ROOT_XML}
		fi

		if [ "" == "$(grep -F "${JNDI_NAME}" ${ROOT_XML})" ]; then
			mv ${ROOT_XML} ${ROOT_XML}.old
			grep -vF '</Context>' ${ROOT_XML}.old > ${ROOT_XML}
			echo '
	<Resource name="'${JNDI_NAME}'"
		auth="Container"
		type="javax.sql.DataSource"
		factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
		driverClassName="'${DRIVER_CLASS_NAME}'"
		url="'$(echo ${DRIVER_URL} | sed 's/&/&amp;/g')'"
		username="'$(echo ${USERNAME} | sed 's/&/&amp;/g')'"
		password="'$(echo ${PASSWORD} | sed 's/&/&amp;/g')'"
		maxActive="20" maxIdle="5" />
</Context>' >> ${ROOT_XML}
		fi
	fi

	# Generate a JDBC connection URL for JGroups

	local CONNECT_OPTIONS=

	if [ "" != "${JNDI_NAME}" ]; then
		CONNECT_OPTIONS='
datasource_jndi_name="java:comp/env/'${JNDI_NAME}'"
'
	else
		CONNECT_OPTIONS='
connection_driver="'${DRIVER_CLASS_NAME}'"
connection_url="'$(echo ${DRIVER_URL} | sed 's/&/&amp;/g')'"
connection_username="'$(echo ${USERNAME} | sed 's/&/&amp;/g')'"
connection_password="'$(echo ${PASSWORD} | sed 's/&/&amp;/g')'"
'
	fi

	# Choose the binary data type

	local BINARY_DATA_TYPE=

	if [ "" == "${DRIVER_CLASS_NAME}" ] || [ "org.hsqldb.jdbc.JDBCDriver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='varbinary(5000)'
	elif [ "org.mariadb.jdbc.Driver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='longblob'
	elif [ "com.mysql.jdbc.Driver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='longblob'
	elif [ "oracle.jdbc.OracleDriver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='blob'
	elif [ "org.postgresql.Driver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='bytea'
	elif [ "com.microsoft.sqlserver.jdbc.SQLServerDriver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='image'
	elif [ "com.sybase.jdbc4.jdbc.SybDriver" == "${DRIVER_CLASS_NAME}" ]; then
		BINARY_DATA_TYPE='image'
	else
		BINARY_DATA_TYPE='varbinary(5000)'
	fi

	# Use the binary data type to generate the correct create table statement

	local EXTRA_OPTIONS='
initialize_sql="CREATE TABLE JGROUPSPING (own_addr varchar(200) NOT NULL, cluster_name varchar(200) NOT NULL, ping_data '${BINARY_DATA_TYPE}', constraint PK_JGROUPSPING PRIMARY KEY (own_addr, cluster_name))"
'

	# Generate a new tcp.xml with the proper JDBC_PING configuration

	sed -n '1,/<TCPPING/p' tcp.xml | sed '$d' > tcp.xml.jdbcping
	echo "<JDBC_PING ${CONNECT_OPTIONS} ${EXTRA_OPTIONS} />" >> tcp.xml.jdbcping
	sed -n '/<MERGE/,$p' tcp.xml >> tcp.xml.jdbcping

	cp -f tcp.xml.jdbcping tcp.xml
	rm tcp.xml.jdbcping
}

tcp_cluster