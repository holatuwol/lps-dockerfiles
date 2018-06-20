FROM jboss/wildfly:10.0.0.Final

EXPOSE 8000 8080 11311

ENV IS_UPGRADE false
ENV BASE_BRANCH	master

ENV LIFERAY_HOME /opt/jboss
ENV WILDFLY_HOME ${LIFERAY_HOME}/wildfly
ENV APP_SERVER wildfly

ENV LICENSE_MIRROR http://10.50.0.165/licenses

ENV LIFERAY_FILES_MIRROR http://172.16.168.221/files.liferay.com
ENV LIFERAY_RELEASES_MIRROR http://172.16.168.221/releases.liferay.com

COPY *.sh /opt/jboss/

ADD standalone.xml ${WILDFLY_HOME}/standalone/configuration/
ADD standalone.sh ${WILDFLY_HOME}/bin/

ENTRYPOINT ["/opt/jboss/entrypoint.sh"]