https://issues.liferay.com/browse/LPS-57166

Steps for 7.0.x
---------------

1.  Start a Docker container with a pre-built ``cas.war`` that allows HTTP service providers.

.. code-block:: bash

	docker run --name LPS-57166 -p 8443:8443 holatuwol/liferayissue:LPS-57166

2.  Navigate to https://localhost:8443/cas and confirm that you can login as the default CAS user, username ``casuser``, password ``Mellon``

3.  Copy ``thekeystore`` from the container to the Tomcat folder for your Tomcat bundle.

.. code-block:: bash

	cd /path/to/catalina/home
	docker cp LPS-57166:/etc/cas/thekeystore .

4.  Open ``setenv.sh`` for your Tomcat bundle and update ``CATALINA_OPTS`` to accept the certificates in the CAS keystore.

.. code-block:: bash

	CATALINA_OPTS="${CATALINA_OPTS} -Djavax.net.ssl.trustStore=${CATALINA_HOME}/thekeystore -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.keyStoreType=jks"

5.  Start up Liferay and log in as the admin user
6.  Navigate to Control Panel > Configuration > Instance Settings
7.  Select the Authentication section
8.  Update the configuration to login by screen name and save the configuration
9.  Select the Authentication section, and click on the CAS tab
10. Update the form fields to be the following, and click on the Test CAS Configuration button to confirm that all values pass:

    a. Login URL: https://localhost:8443/cas/login
    b. Logout URL: https://localhost:8443/cas/logout
    c. Server Name: http://localhost:8080
    d. Server URL: https://localhost:8443/cas
    e. Service URL: http://localhost:8080/c/portal/login
    f. No Such User Redirect URL: http://localhost:8080

11. Check the "Enabled" checkbox and save the configuration.
12. Create a new user with the screen name "casuser" (all other fields do not matter)
13. Open a New Incognito window and click on the Sign In link
14. Sign in as the default CAS user, username ``casuser``, password ``Mellon``
15. Accept the Terms of Use

**Note**: After the error, you will need to delete the casuser and recreate them in order to reproduce the error again. If you are signed out and need to login as the test user, you will need to access the login portlet directly via http://localhost:8080/?p_p_id=com_liferay_login_web_portlet_LoginPortlet&p_p_state=maximized