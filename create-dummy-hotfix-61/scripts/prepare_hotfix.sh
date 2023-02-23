#!/bin/bash

copy_ext_files() {
    mkdir -p /patch/jdk6/${1}
    cp -R /plugins/ext/liferay-hotfix-ext/docroot/WEB-INF/${2}/* /patch/jdk6/${1}/
}

copy_ext_files GLOBAL_LIB_PATH ext-lib/global
copy_ext_files WAR_PATH/WEB-INF/lib ext-lib/portal

copy_ext_files GLOBAL_LIB_PATH/portal-service.jar ext-service/classes
copy_ext_files WAR_PATH/WEB-INF/lib/portal-impl.jar ext-impl/classes

copy_ext_files WAR_PATH/WEB-INF/lib/util-bridges.jar ext-util-bridges/classes
copy_ext_files WAR_PATH/WEB-INF/lib/util-java.jar ext-util-java/classes
copy_ext_files WAR_PATH/WEB-INF/lib/util-taglib.jar ext-util-taglib/classes

copy_ext_files WAR_PATH ext-web/docroot