Steps for 7.0.x
---------------

1.	Start a Docker container with OpenLDAP installed and a password policy with history enabled.

.. code-block:: bash

	docker run --name LPS-76332 --detach -p 389:389 holatuwol/liferayissue:LPS-76332
	docker exec LPS-76332 ldapmodify -x -c -D 'cn=admin,cn=config' -w admin -f /postmodify.ldif

2.	Confirm that you can reset the password for test1 to "test1", which is different from their current password "test"

.. code-block:: bash

	docker exec LPS-76332 ldappasswd -D 'cn=test,ou=people,dc=example,dc=org' -w test -s test1 'cn=test1,ou=people,dc=example,dc=org'

3.	Confirm that you cannot reset the password for test1 to "test1", which is the same as their current password "test1"

.. code-block:: bash

	docker exec LPS-76332 ldappasswd -D 'cn=test,ou=people,dc=example,dc=org' -w test -s test1 'cn=test1,ou=people,dc=example,dc=org'

4.	Start up Liferay and log in as the admin user
5.	Navigate to Control Panel > Configuration > Instance Settings
6.	Select the Authentication section and select the LDAP tab
7.	Choose the option to add an LDAP server
8.	Test the LDAP configuration

	a.	Set the name to "localhost"
	b.	Select the OpenLDAP radio button
	c.	Change the Base DN to "dc=example,dc=org"
	d.	Change the Principal to "cn=test,ou=people,dc=example,dc=org"
	e.	Change the password to "test"
	f.	Click on the "Test LDAP Connection" button

9.	Test the LDAP user import

	a.	Click on the "Test LDAP Users" button

10.	Update the LDAP export configuration

	a.	Change the Users DN to "ou=people,dc=example,dc=org"
	b.	Change the User Default Object Classes to "top,person,organizationalPerson,inetOrgPerson"
	c.	Set the Groups DN to blank

11.	Save the configuration
12.	Select the Authentication section and select the LDAP tab
13.	Check the "Enabled" checkbox, the "Required" checkbox, the "Enable Export" checkbox, and the "Use LDAP Password Policy" checkbox and Save
14.	Sign in as test2@liferay.com with the password "test"
15.	Navigate to My Account > Account Settings
16.	Attempt to change your password to "test1"
