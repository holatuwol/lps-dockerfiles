FROM azul/zulu-openjdk:6u119

ENV TOMCAT_VERSION='7.0.109'

EXPOSE 8000 8080

COPY entrypoint.sh /

RUN chmod u+x /entrypoint.sh

RUN touch /sbin/ifconfig && chmod u+x /sbin/ifconfig

ENTRYPOINT /entrypoint.sh