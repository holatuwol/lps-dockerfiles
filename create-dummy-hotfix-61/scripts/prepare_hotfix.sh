#!/bin/bash

copy_ext_files() {
    mkdir -p patch/jdk6/${1}
    cp -R /plugins/ext/liferay-hotfix-ext/docroot/WEB-INF/${2}/* patch/jdk6/${1}/
}

copy_ext_files GLOBAL_LIB_PATH ext-lib/global
copy_ext_files WAR_PATH/WEB-INF/lib ext-lib/portal

copy_ext_files GLOBAL_LIB_PATH/portal-service.jar ext-service/classes
copy_ext_files WAR_PATH/WEB-INF/lib/portal-impl.jar ext-impl/classes

for file in $(grep '^portal-impl/src/.*properties$' git_diff_name_only.txt | sed 's@portal-impl/src/@@' | grep -vF portal.properties); do
  mkdir -p patch/properties/$(dirname ${file})
  cp portal-impl/src/${file} patch/properties/${file}
done

mkdir -p patch/jdk6/WAR_PATH/WEB-INF/classes/
cp portal-impl/src/portal.properties patch/jdk6/WAR_PATH/WEB-INF/classes/

for file in $(find patch/jdk6/WAR_PATH/WEB-INF/lib/portal-impl.jar -name '*.properties' | sed 's@^.*/portal-impl.jar/@@g'); do
  mkdir -p patch/properties/$(dirname "${file}")
  mv patch/jdk6/WAR_PATH/WEB-INF/lib/portal-impl.jar/${file} patch/properties/${file}
done

copy_ext_files WAR_PATH/WEB-INF/lib/util-bridges.jar ext-util-bridges/classes
copy_ext_files WAR_PATH/WEB-INF/lib/util-java.jar ext-util-java/classes
copy_ext_files WAR_PATH/WEB-INF/lib/util-taglib.jar ext-util-taglib/classes

copy_ext_files WAR_PATH ext-web/docroot

cp portal-web/docroot/WEB-INF/web.xml patch/jdk6/WAR_PATH/WEB-INF/