FROM azul/zulu-openjdk:6u119

ENV ANT_VERSION='1.9.16'
ENV ANT_OPTS='-Xmx2g'
ENV TOMCAT_VERSION='7.0.109'

RUN apt -o "Acquire::https::Verify-Peer=false" update && apt install -y git unzip

RUN mkdir /opt/java

ADD apache-ant-${ANT_VERSION}-bin.tar.gz /opt/java/

RUN ln -s /opt/java/apache-ant-${ANT_VERSION} /opt/java/ant

COPY ecj-3.6.jar /opt/java/ant/lib/ecj.jar

COPY apache-tomcat-${TOMCAT_VERSION}.zip /

COPY liferay-plugins-sdk-6.1.1-ce-ga2-20121004092655026.zip /

RUN unzip -qq /liferay-plugins-sdk-6.1.1-ce-ga2-20121004092655026.zip && \
    mv /liferay-plugins-sdk-6.1.1 /plugins && \
    chmod u+x /plugins/ext/create.sh && \
    mkdir -p /bundles

COPY Miniconda3-latest-Linux-x86_64.sh /

RUN chmod u+x /Miniconda3-latest-Linux-x86_64.sh && \
    /Miniconda3-latest-Linux-x86_64.sh -b -p /miniconda3

RUN /miniconda3/bin/conda init && \
    /miniconda3/bin/conda install -y beautifulsoup4 lxml

RUN mkdir -p /scripts/

COPY scripts/* /scripts/
COPY entrypoint.sh /

RUN chmod u+x /scripts/*.sh && chmod u+x /entrypoint.sh

ENTRYPOINT /entrypoint.sh