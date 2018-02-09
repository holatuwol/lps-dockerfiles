FROM openjdk:7-jdk

EXPOSE 7800 7801 8000 8009 8080 11311

ENV LIFERAY_HOME /opt/liferay
ENV IS_UPGRADE false
ENV BASE_BRANCH	master

ENV BRANCH_ARCHIVE_MIRROR http://10.50.0.165/builds/branches
ENV TAG_ARCHIVE_MIRROR http://10.50.0.165/builds/fixpacks
ENV LICENSE_MIRROR http://10.50.0.165/licenses

ENV LIFERAY_FILES_MIRROR http://172.16.168.221/files.liferay.com
ENV LIFERAY_RELEASES_MIRROR http://172.16.168.221/releases.liferay.com

RUN	apt-get update && \
	apt-get install -y --no-install-recommends curl groovy net-tools rsync telnet unzip vim && \
	useradd -ms /bin/bash liferay && \
	mkdir -p /opt/liferay/data && \
	chown -R liferay:liferay /opt/liferay

COPY entrypoint.sh /home/liferay/
COPY common.sh /home/liferay/
COPY bundle.sh /home/liferay/
COPY upgrade.sh /home/liferay/

RUN chown liferay:liferay /home/liferay/*.sh && \
	chmod u+x /home/liferay/*.sh

USER liferay

ENTRYPOINT ["/home/liferay/entrypoint.sh"]