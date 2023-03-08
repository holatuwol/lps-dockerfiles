#!/bin/bash

copy_ext_file() {
  if [ ! -f ${2} ]; then
    return
  fi

  mkdir -p "/plugins/ext/liferay-hotfix-ext/docroot/WEB-INF/${1}/$(dirname "${2}")/"
  cp "${2}" "/plugins/ext/liferay-hotfix-ext/docroot/WEB-INF/${1}/${2}"
}

# Generate a clean EXT plugin

rm -rf "/plugins/ext/liferay-hotfix-ext"

cd "/plugins/ext"
./create.sh liferay-hotfix "LiferayHotfix"
cd -

# Copy the jars we need from lib/development to the EXT plugins SDK lib folder
# Copy the contents of lib/global and lib/portal to the equivalent EXT plugin folder

cd /source/lib

for jar in resin.jar; do
  cp development/${jar} "/plugins/lib/"
  sed -i "/servlet-api.jar/s/,servlet-api.jar/,servlet-api.jar,${jar}/g" /plugins/build-common.xml
done

for folder in global portal; do
  for file in $(grep "^lib/${folder}" ../git_diff_name_only.txt | sed 's@^lib/@@g'); do
    copy_ext_file ext-lib ${file}
  done
done

# Copy the contents of portal-service and portal-impl to the equivalent EXT plugin folder

for folder in service impl; do
  cd /source/portal-${folder}/src/

  for file in $(grep "^portal-${folder}/src/" ../../git_diff_name_only.txt | grep -vF .properties | sed "s@^portal-${folder}/src@.@g"); do
    copy_ext_file ext-${folder}/src ${file}
  done
done

# Copy the contents of util-bridges, util-java, util-taglib to the equivalent EXT plugin folder

for folder in bridges java taglib; do
  cd /source/util-${folder}/src/

  for file in $(grep "^util-${folder}/src/" ../../git_diff_name_only.txt | sed "s@^util-${folder}/src@.@g"); do
    copy_ext_file ext-util-${folder}/src ${file}
  done
done

# Copy the contents of portal-web to the equivalent EXT plugin folder

cd /source/portal-web/docroot/

for file in $(grep "^portal-web/docroot/" ../../git_diff_name_only.txt | sed "s@^portal-web/docroot@.@g"); do
  copy_ext_file ext-web/docroot ${file}
done

# Generate a build.${USER}.properties if it's missing, and if we know where the app server is

cd /plugins/ext/liferay-hotfix-ext
ant compile