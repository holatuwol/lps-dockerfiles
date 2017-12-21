#!/bin/bash

addheader() {
	echo "# Define password policy

dn: ou=policies,dc=example,dc=org
objectClass: organizationalUnit
ou: policies

dn: cn=default,ou=policies,dc=example,dc=org
objectClass: applicationProcess
objectClass: pwdPolicy
cn: default
pwdAllowUserChange: TRUE
pwdAttribute: userPassword
pwdCheckQuality: 1
# 7 days
pwdExpireWarning: 604800
pwdFailureCountInterval: 0
pwdGraceAuthNLimit: 0
pwdInHistory: 5
pwdLockout: TRUE
# 30 minutes
pwdLockoutDuration: 1800
# 180 days
pwdMaxAge: 15552000
pwdMaxFailure: 5
pwdMinAge: 0
pwdMinLength: ${1}
pwdMustChange: TRUE
pwdSafeModify: FALSE

# Define user organizational unit

dn: ou=people,dc=example,dc=org
objectClass: organizationalUnit
ou: people
" > prepopulate.ldif

}

adduser() {
	local cn=$(echo ${1} | cut -d',' -f 1)
	local pw=$(echo ${1} | cut -d',' -f 2)
	local gn=$(echo ${1} | cut -d',' -f 3)
	local sn=$(echo ${1} | cut -d',' -f 4)

echo -n "
dn: cn=${cn},ou=people,dc=example,dc=org
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectClass: inetOrgPerson
givenname: ${gn}
sn: ${sn}
cn: ${cn}
uid: ${cn}
telephonenumber: 543-3729
userpassword: ${pw}
mail: ${cn}@liferay.com
" >> prepopulate.ldif

}

if [ "" == "${1}" ]; then
	echo "No minimum password length specified, assuming 1"
	addheader 1
else
	echo "Requiring minimum password length of ${1}"
	addheader ${1}
fi

echo '# Create the test administrator user' >> prepopulate.ldif

adduser $(head -1 users.csv)

echo '
# Create other sample users' >> prepopulate.ldif

for line in $(tail -n +2 users.csv); do
	adduser $line
done

perl -pi -e 'chomp if eof' prepopulate.ldif