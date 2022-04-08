FROM liferay/dxp:7.3.10-dxp-3

USER root

RUN sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list && \
    apt update && \
    apt install -y build-essential autoconf libtool git-core wget && \
    apt build-dep -y libde265 libheif

RUN cd /usr/src && \
    git clone https://github.com/strukturag/libde265.git && \
    cd libde265/ && ./autogen.sh && ./configure && make && make install 

RUN cd /usr/src && \
    git clone https://github.com/strukturag/libheif.git && \
    cd libheif/ && ./autogen.sh && ./configure && make && make install 

RUN cd /usr/src/ && \
    wget https://www.imagemagick.org/download/ImageMagick.tar.gz && \
    tar -xf ImageMagick.tar.gz && \
    cd ImageMagick-7* && ./configure --with-heic=yes && make && make install

RUN ldconfig

USER liferay

COPY portal-ext.properties /opt/liferay/

ENV LIFERAY_JPDA_ENABLED=true