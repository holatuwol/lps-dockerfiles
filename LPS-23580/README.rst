Docker Setup
------------

1.	Start a Docker container with a MySQL database which has a binary collation by default

.. code-block:: bash

	docker run --name LPS-23580 --rm --detach holatuwol/liferayissue:LPS-23580

2.	Find the IP address of the container

.. code-block:: bash

	docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' LPS-23580

3.	Add the following to ``portal-ext.properties``, replacing ``IP_ADDRESS`` with the value detected above

.. code-block:: properties

	jdbc.default.driverClassName=com.mysql.jdbc.Driver
	jdbc.default.url=jdbc:mysql://IP_ADDRESS/lportal?characterEncoding=UTF-8&dontTrackOpenResources=true&holdResultsOpenOverStatementClose=true&useFastDateParsing=false&useUnicode=true
	jdbc.default.username=lportal
	jdbc.default.password=lportal

4.	Startup Liferay and log in as the admin user
5.	Access the Control Panel menu and select Content > Wiki
6.	Select the "List" view
7.	Publish a page with the name "A"
8.	Publish another page with the name "b"
9.	Publish another page with the name "C"
10.	Publish another page with the name "d"