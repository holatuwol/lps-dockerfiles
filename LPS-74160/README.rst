Steps for 7.0.x
---------------

1.	Start a Docker container with OpenLDAP installed, a password policy that requires all passwords have 16 or more characters, the test (omniadmin) user, and ten sample users all with the password "thisis18characters"

.. code-block:: bash

	docker run --name LPS-74160 --detach -p 389:389 holatuwol/liferayissue:LPS-74160
	docker exec LPS-74160 ldapmodify -x -c -D 'cn=admin,cn=config' -w admin -f /postmodify.ldif

2.	Confirm that you can reset the password for test1 to "thisismorethan16characters", which contains more than 16 characters

.. code-block:: bash

	docker exec LPS-74160 ldappasswd -D 'cn=test,ou=people,dc=example,dc=org' -w test -s thisismorethan16characters 'cn=test1,ou=people,dc=example,dc=org'

3.	Confirm that you cannot reset the password for test1 to "shorterpassword", which contains 15 characters

.. code-block:: bash

	docker exec LPS-74160 ldappasswd -D 'cn=test,ou=people,dc=example,dc=org' -w test -s shorterpassword 'cn=test1,ou=people,dc=example,dc=org'

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
14.	Sign in as test2@liferay.com with the password "thisis18characters"
15.	Navigate to My Account > Account Settings
16.	Attempt to change your password to "shorterpassword", which contains 15 characters


Steps for 6.2.x
---------------

1.	Start a Docker container with OpenLDAP installed, a password policy that requires all passwords have 16 or more characters, the test (omniadmin) user, and ten sample users all with the password "thisis18characters"

.. code-block:: bash

	docker run --name LPS-74160 --detach -p 389:389 holatuwol/liferayissue:LPS-74160
	docker exec LPS-74160 ldapmodify -x -c -D 'cn=admin,cn=config' -w admin -f /postmodify.ldif

2.	Confirm that you can reset the password for test1 to "thisismorethan16characters", which contains more than 16 characters

.. code-block:: bash

	docker exec LPS-74160 ldappasswd -D 'cn=test,ou=people,dc=example,dc=org' -w test -s thisismorethan16characters 'cn=test1,ou=people,dc=example,dc=org'

3.	Confirm that you cannot reset the password for test1 to "shorterpassword", which contains 15 characters

.. code-block:: bash

	docker exec LPS-74160 ldappasswd -D 'cn=test,ou=people,dc=example,dc=org' -w test -s shorterpassword 'cn=test1,ou=people,dc=example,dc=org'

4.	Start up Liferay and log in as the admin user

5.	Navigate to Admin > Control Panel and click on Portal Settings

6.	Select the Authentication section and select the LDAP tab

7.	Choose the option to add an LDAP server

8.	Test the LDAP configuration

	a.	Set the name to "localhost"
	b.	Select the OpenLDAP radio button and click on the "Reset Values" button
	c.	Set the Base Provider URL to "ldap://localhost:389"
	d.	Change the Base DN to "dc=example,dc=org"
	e.	Change the Principal to "cn=test,ou=people,dc=example,dc=org"
	f.	Change the password to "test"
	g.	Click on the "Test LDAP Connection" button

9.	Test the LDAP user import

	a.	Click on the "Test LDAP Users" button

10.	Update the LDAP export configuration

	a.	Change the Users DN to "ou=people,dc=example,dc=org"
	b.	Change the User Default Object Classes to "top,person,organizationalPerson,inetOrgPerson"
	c.	Set the Groups DN to blank

11.	Save the configuration
12.	Select the Authentication section and select the LDAP tab
13.	Check the "Enabled" checkbox, the "Required" checkbox, the "Export Enabled" checkbox, and the "Use LDAP Password Policy" checkbox and Save
14.	Sign in as test2@liferay.com with the password "thisis18characters"
15.	Navigate to My Account
16.	Attempt to change your password to "shorterpassword", which contains 15 characters