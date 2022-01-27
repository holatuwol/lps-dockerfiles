FROM jboss/wildfly:23.0.2.Final

EXPOSE 7800 7801 8000 8080 9990 11311

ENV LIFERAY_HOME /opt/jboss
ENV JVM_HEAP_SIZE 2g
ENV JVM_META_SIZE 512m

ENV WILDFLY_HOME ${LIFERAY_HOME}/wildfly
ENV APP_SERVER wildfly

COPY *.sh /opt/jboss/

ADD standalone.xml ${WILDFLY_HOME}/standalone/configuration/

ENTRYPOINT ["/opt/jboss/entrypoint.sh"]