https://issues.liferay.com/browse/LPS-85179

1.	Start a Docker container with OpenLDAP installed.

.. code-block:: bash

	docker run --name LPS-85179 --detach -p 389:389 holatuwol/liferayissue:LPS-85179
	docker exec -u root LPS-85179 apt-get update
	docker exec -u root LPS-85179 apt-get install -yq ldap-utils
	docker exec LPS-85179 ldapmodify -x -c -D 'cn=admin,cn=config' -w admin -f /postmodify.ldif

2.	Start up Liferay and log in as the admin user
3.	Navigate to Control Panel > Configuration > Instance Settings
4.	Select the Authentication section and select the LDAP tab
5.	Choose the option to add an LDAP server
6.	Test the LDAP configuration

	a.	Set the name to "localhost"
	b.	Select the OpenLDAP radio button
	c.	Change the Base DN to "dc=example,dc=org"
	d.	Change the Principal to "cn=test,ou=people,dc=example,dc=org"
	e.	Change the password to "test"
	f.	Click on the "Test LDAP Connection" button

7.	Test the LDAP user import

	a.	Click on the "Test LDAP Users" button

8.	Save the configuration
9.	Select the Authentication section and select the LDAP tab
10.	Check the "Enabled" checkbox, the "Required" checkbox, and the "Enable User Password on Import" checkbox
11. Save the configuration, and double-check to make sure the settings took effect
12. Open a new shell window, and run the following script. If not using the provided OpenLDAP server, update the value for ``-u`` accordingly.

.. code-block:: bash

	while true
	do
		curl http://localhost:8080/api/jsonws/classname/fetch-class-name -u 'test2@liferay.com:test' -d 'value=com.liferay.portal.kernel.model.User'
	done

13. Confirm that the script successfully runs successfully
14. Open a new shell window, and run the above script again (essentially having two shell windows running the script in parallel)