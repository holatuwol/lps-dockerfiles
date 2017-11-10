.. contents:: :local:

Initial Setup
-------------

1. Clone this repository.

2. Update the environment variables in Dockerfile to reflect your local office's internal mirrors. The default values are for Liferay's Diamond Bar office.

.. code-block:: text

	ENV LIFERAY_HOME /opt/liferay
	ENV BASE_BRANCH	master

	ENV BRANCH_ARCHIVE_MIRROR http://10.50.0.165/builds/branches
	ENV TAG_ARCHIVE_MIRROR http://10.50.0.165/builds/fixpacks

	ENV LIFERAY_FILES_MIRROR http://172.16.168.221/files.liferay.com
	ENV LIFERAY_RELEASES_MIRROR http://172.16.168.221/releases.liferay.com

3. Navigate to the folder within your local computer and run the following command to create a local image named ``liferay-nightly-build``.

.. code-block:: bash

	docker build /path/to/repository/nightly -t liferay-nightly-build

Basic Usage
-----------

1. If you want to just spin up a nightly build of master running on Hypersonic, you can use the following command.

.. code-block:: bash

	docker run --name LESATICKET-ID liferay-nightly-build

2. You can access the Tomcat instance by finding the IP address, which can be done with the following command.

.. code-block:: bash

	docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' LESATICKET-ID

Provide Additional Files
~~~~~~~~~~~~~~~~~~~~~~~~

If you mount any of your local folders to ``/build``, the script will use ``rsync`` in order to copy **all** files within that folder into ``LIFERAY_HOME`` as an initial step for preparing the container.

.. code-block:: bash

	docker run --name LESATICKET-ID --volume /path/to/local/folder:/build liferay-nightly-build

The initialization script will use files located in this ``/build`` folder in order to provide the following capabilities:

* If you put a ``portal-ext.properties`` at the root of this local folder, this will allow Liferay to use this ``portal-ext.properties`` for its build.
* If you create a ``drivers`` folder in your local folder, it will copy the contents of this folder to ``CATALINA_HOME/lib/ext`` which allows you to use non-Hypersonic databases with a nightly build.
* If you create a ``patches`` folder in your local folder that is mounted to ``/build``, the initialization script will download a release bundle from the ``files.liferay.com`` mirror rather than use a nightly build, and Patching Tool will be run to apply those patches.

Note that this capability also means that you can use a pre-built Liferay, which is described more in detail below.

Run Modes
---------

Run a Nightly Build
~~~~~~~~~~~~~~~~~~~

The default behavior if no special environment variables are set is to attempt to download a nightly build of master. You can specify whether you want to test against 7.0.x by providing the ``BASE_BRANCH`` environment variable or you can pass the branch as an argument.

.. code-block:: bash

	docker run --name LESATICKET-ID -e BASE_BRANCH=7.0.x liferay-nightly-build
	docker run --name LESATICKET-ID liferay-nightly-build 7.0.x

Run a Release
~~~~~~~~~~~~~

You can specify a release build by provide the ``RELEASE_ID`` environment variable. CE releases have the form ``7.0.0-ga1``, where the value corresponds to a tag on the ``liferay-portal`` repository, while EE releases have the form ``7.0.10.1``, where the point release corresponds to the service pack of the release or you can pass the name of the release as an argument.

.. code-block:: bash

	docker run --name LESATICKET-ID -e RELEASE_ID=7.0.10.6 liferay-nightly-build
	docker run --name LESATICKET-ID liferay-nightly-build 7.0.10.6

Apply a Fix Pack or Hotfix
~~~~~~~~~~~~~~~~~~~~~~~~~~

As noted above, you can provide a ``patches`` folder and it will automatically attempt to patch a release bundle. If you do not specify a ``RELEASE_ID``, the initialization script will assume you wish to patch the initial release of 7.0.10. You can have it patch a different release by providing a ``RELEASE_ID``, as described above.

Alternately, you can provide the name of the patch as a ``PATCH_ID`` environment variable or pass the patch ID as an argument. This environment variable allows for shorthand (``de-1``, ``hotfix-1``) and for a longer form (``liferay-fix-pack-de-1-7010``, ``liferay-hotfix-1-7010``).

.. code-block:: bash

	docker run --name LESATICKET-ID -e PATCH_ID=de-1 liferay-nightly-build
	docker run --name LESATICKET-ID liferay-nightly-build de-1

Run a Fix Pack (No License)
~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you wish to run a fix pack built from source, you can specify a DE fix pack built from source by providing the ``BASE_TAG`` environment variable. Note that if you wish to use a patched DE fix pack rather than one from source, you will need to use the ``patches`` folder instead of specifying a fix pack tag.

.. code-block:: bash

	docker run --name LESATICKET-ID -e BASE_TAG=fix-pack-de-1-7010 liferay-nightly-build

Run a Local Build
~~~~~~~~~~~~~~~~~

If a Tomcat bundle already exists in the folder specified by the ``build`` folder mounted from your local system, this Tomcat bundle will be copied instead of a new Tomcat bundle being downloaded from the nightly build servers. This allows you to container-ize a local build of Liferay.

.. code-block:: bash

	docker run --name LESATICKET-ID --volume /path/to/local/liferay/home:/build liferay-nightly-build
