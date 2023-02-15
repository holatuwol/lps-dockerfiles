FROM azul/zulu-openjdk:6u119

ENV ANT_VERSION='1.9.16'
ENV ANT_OPTS='-Xmx2g'
ENV TOMCAT_VERSION='7.0.109'

RUN mkdir /opt/java

ADD apache-ant-${ANT_VERSION}-bin.tar.gz /opt/java/

RUN ln -s /opt/java/apache-ant-${ANT_VERSION} /opt/java/ant

COPY ecj-3.6.jar /opt/java/ant/lib/ecj.jar

COPY apache-tomcat-${TOMCAT_VERSION}.zip /

COPY entrypoint.sh /

RUN chmod u+x /entrypoint.sh

ENTRYPOINT /entrypoint.sh