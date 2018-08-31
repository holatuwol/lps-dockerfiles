FROM ibmcom/ibmjava:8-sdk

EXPOSE 7800 7801 8000 8009 8080 11311

ENV LIFERAY_HOME /opt/liferay
ENV IS_UPGRADE false
ENV BASE_BRANCH	master
ENV JVM_HEAP_SIZE 2g

ENV TAG_ARCHIVE_MIRROR http://10.0.30.27/builds/fixpacks
ENV LICENSE_MIRROR http://10.50.0.165/licenses

ENV LIFERAY_FILES_MIRROR http://172.16.168.221/files.liferay.com
ENV LIFERAY_RELEASES_MIRROR http://172.16.168.221/releases.liferay.com

RUN	apt-get update && \
	apt-get install -y --no-install-recommends curl net-tools rsync telnet unzip vim && \
	rm -rf /var/lib/apt/lists/* && \
	useradd -ms /bin/bash liferay && \
	mkdir -p /opt/liferay/data && \
	chown -R liferay:liferay /opt/liferay

COPY *.sh /home/liferay/
COPY sslconfig.cnf.base /home/liferay/

RUN chown liferay:liferay /home/liferay/*.sh && \
	chmod u+x /home/liferay/*.sh

USER liferay

ENTRYPOINT ["/home/liferay/entrypoint.sh"]