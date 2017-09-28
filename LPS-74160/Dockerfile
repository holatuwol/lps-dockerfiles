FROM dinkel/openldap

ENV	SLAPD_PASSWORD=admin
ENV	SLAPD_CONFIG_PASSWORD=admin
ENV	SLAPD_DOMAIN=example.org
ENV	SLAPD_ADDITIONAL_SCHEMAS=ppolicy
ENV	SLAPD_ADDITIONAL_MODULES=ppolicy

RUN	apt-get update && \
	apt-get install -y ldap-utils

ADD	prepopulate.ldif /etc/ldap.dist/prepopulate/
ADD	postmodify.ldif /