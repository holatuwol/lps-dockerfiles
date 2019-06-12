FROM jboss/wildfly:11.0.0.Final

EXPOSE 7800 7801 8000 8080 9990 11311

ENV LIFERAY_HOME /opt/jboss
ENV IS_UPGRADE false
ENV BASE_BRANCH	master
ENV JVM_HEAP_SIZE 2g
ENV JVM_META_SIZE 512m

ENV TAG_ARCHIVE_MIRROR http://10.0.30.27/builds/fixpacks
ENV LICENSE_MIRROR http://10.50.0.165/licenses

ENV LIFERAY_FILES_MIRROR http://172.16.168.221/files.liferay.com
ENV LIFERAY_RELEASES_MIRROR http://172.16.168.221/releases.liferay.com

ENV WILDFLY_HOME ${LIFERAY_HOME}/wildfly
ENV APP_SERVER wildfly

COPY *.sh /opt/jboss/

ADD standalone.xml ${WILDFLY_HOME}/standalone/configuration/
ADD standalone.sh ${WILDFLY_HOME}/bin/

ENTRYPOINT ["/opt/jboss/entrypoint.sh"]