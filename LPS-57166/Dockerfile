FROM apereo/cas:v5.1.6

RUN mkdir -p /cas-overlay/src/main/resources/services

COPY pom.xml /cas-overlay/
COPY http-101.json /cas-overlay/src/main/resources/services/

RUN	./build.sh package

COPY sslconfig.cnf /cas-overlay/
COPY create_keystore.sh /cas-overlay/

RUN yum install -y openssl && \
	chmod u+x create_keystore.sh && \
	./create_keystore.sh