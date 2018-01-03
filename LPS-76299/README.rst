Docker Setup
------------

1.	Start a Docker container with a pre-created Blade workspace with a sample service builder project

.. code-block:: bash

	docker run --name LPS-76299 --rm --detach holatuwol/liferayissue:LPS-76299

2.	Navigate to your ``LIFERAY_HOME`` folder

.. code-block:: bash

	cd /path/to/liferay/home

3.	Deploy the sample service builder project to your local installation

.. code-block:: bash

	docker exec LPS-76299 /deploy.sh
	docker cp LPS-76299:/LPS-76299/bundles/osgi/modules/com.example.mismatch.api.jar osgi/modules/
	docker cp LPS-76299:/LPS-76299/bundles/osgi/modules/com.example.mismatch.service.jar osgi/modules/
	docker cp LPS-76299:/LPS-76299/bundles/osgi/modules/com.example.mismatch.web.jar osgi/modules/

4.	Startup Liferay, login as a portal administrator, and add the example-schema-mismatch-web Portlet to a page

5.	Deploy a rolled back version of the sample service builder project to your local installation

.. code-block:: bash

	docker exec LPS-76299 /deploy.sh 0.9.0
	docker cp LPS-76299:/LPS-76299/bundles/osgi/modules/com.example.mismatch.service.jar osgi/modules/


Manual Setup
------------

1.	Install Blade CLI (see `Installing Blade CLI <https://dev.liferay.com/develop/tutorials/-/knowledge_base/7-0/installing-blade-cli>`__ for instructions)

2.	Create a Blade workspace

.. code-block:: bash

	mkdir LPS-76299
	blade init LPS-76299

3.	Update ``gradle.properties`` inside of the root of your Blade workspace to point to your ``LIFERAY_HOME`` folder

.. code-block:: properties

	liferay.workspace.home.dir=/path/to/liferay/home

4.	Navigate to the ``modules`` folder and create a service builder module

.. code-block:: bash

	cd LPS-76299/modules
	blade create -t service-builder -p com.example.mismatch example-schema-mismatch

5.	Build the sample services project

.. code-block:: bash

	blade gw :modules:example-schema-mismatch:example-schema-mismatch-service:buildService

6.	Deploy the jars for the the ``example-schema-mismatch-api`` and ``example-schema-mismatch-service`` projects

.. code-block:: bash

	blade gw :modules:example-schema-mismatch:example-schema-mismatch-api:deploy :modules:example-schema-mismatch:example-schema-mismatch-service:deploy

7.	Create a simple portlet project named ``example-schema-mismatch-web``

.. code-block:: bash

	blade create -t mvc-portlet -p com.example.mismatch.web example-schema-mismatch-web

8.	Update the ``build.gradle`` for ``example-schema-mismatch-web`` to contain a dependency on the ``example-schema-mismatch-api`` by adding the following to the ``dependencies`` block:

.. code-block:: groovy

	compileOnly project(":modules:example-schema-mismatch:example-schema-mismatch-api")

9.	Update ``src/main/java/com/example/mismatch/web/portlet/ExampleSchemaMismatchPortlet.java`` in ``example-schema-mismatch-web`` so that it contains a reference to the service from ``example-schema-mismatch-api``:

.. code-block:: java

	import org.osgi.service.component.annotations.Reference;
	import com.example.mismatch.service.FooLocalService;

	// ...

	@Reference
	private FooLocalService _fooLocalService;

10.	Deploy the jar for the ``example-schema-mismatch-web`` project

.. code-block:: bash

	blade gw :modules:example-schema-mismatch-web:deploy

11.	Startup Liferay, login as a portal administrator and add the example-schema-mismatch-web Portlet to a page

12.	Update the ``Bundle-Version`` and ``Liferay-Require-SchemaVersion`` specified in the ``bnd.bnd`` for ``example-schema-mismatch-service`` to 0.9.0 to simulate a rollback in schema version

.. code-block:: text

	Bundle-Version: 0.9.0
	Liferay-Require-SchemaVersion: 0.9.0

13.	Deploy the jar for the ``example-schema-mismatch-service`` project

.. code-block:: bash

	blade gw :modules:example-schema-mismatch:example-schema-mismatch-service:deploy