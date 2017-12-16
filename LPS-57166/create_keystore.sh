#!/bin/bash

echo | openssl req -config sslconfig.cnf -new -sha256 -newkey rsa:2048 \
	-nodes -keyout server.key -x509 -days 365 \
	-out server.crt

openssl pkcs12 -export \
	-in server.crt -inkey server.key -passin pass:'' \
	-out server.p12 -passout pass:'' -name tomcat

keytool -importkeystore -destkeypass changeit \
	-deststorepass changeit -destkeystore /etc/cas/thekeystore \
	-srckeystore server.p12 -srcstorepass '' -srcstoretype PKCS12 -alias tomcat