FROM openjdk:8-jdk

RUN	apt-get update && \
	apt-get install -y --no-install-recommends curl net-tools rsync unzip && \
	useradd -ms /bin/bash liferay && \
	mkdir /opt/liferay && \
	chown liferay:liferay /opt/liferay

USER liferay

EXPOSE 8000 8009 8080 11311

ENV LIFERAY_HOME /opt/liferay
ENV BASE_BRANCH	master

ENV BRANCH_ARCHIVE_MIRROR http://10.50.0.165/builds/branches
ENV TAG_ARCHIVE_MIRROR http://10.50.0.165/builds/fixpacks

ENV LIFERAY_FILES_MIRROR http://172.16.168.221/files.liferay.com
ENV LIFERAY_RELEASES_MIRROR http://172.16.168.221/releases.liferay.com

COPY entrypoint.sh /home/liferay/

ENTRYPOINT ["/home/liferay/entrypoint.sh"]