ARG BUILD_FROM=${BUILD_FROM}

FROM ${BUILD_FROM}

ENV LANG C.UTF-8

RUN apk add --no-cache \
  bc \
  coreutils \
  curl \
  dateutils \
  findutils \
  gettext \
  gawk \
  jq \
  openssl-dev \
  git

RUN apk add --no-cache \
  python3

RUN apk add --no-cache \
  inotify-tools \
  mosquitto-clients

RUN apk add --no-cache \
  apache2 \
  apache2-utils

RUN apk add --no-cache \
  imagemagick

RUN apk add --no-cache \
  tcsh@edge

RUN apk add --no-cache \
  ffmpeg@edge \
  motion@edge

## LIVE555
RUN \
    apk add --no-cache \
	live-media-dev \
	git \
	g++ \
	make \
    \
    && apk add --no-cache \
	live-media-utils

RUN \
    cd /tmp \
    && \
    git clone https://github.com/dcmartin/live555.git \
    && \
    cd live555 \
    && \
    sed -i -e 's/proxyStream\-\%d/stream%02d/g' ./proxyServer/live555ProxyServer.cpp \
    && \
    sed -i -e "s/proxyStream/stream/g" ./proxyServer/live555ProxyServer.cpp \
    && \
    ./genMakefiles linux

RUN \
    cd /tmp/live555 \
    && \
    make -j4

RUN \
    cd /tmp/live555 \
    && \
    cp proxyServer/live555ProxyServer /usr/local/bin/

RUN \
    rm -rf /tmp/*

RUN apk add --no-cache \
  openssh-client

# environment
ENV CONFIG_PATH /data/options.json
ENV MOTION_CONF /etc/motion/motion.conf

# Copy rootts
COPY rootfs /

## APACHE

#ARG APACHE_CONF=/etc/apache2/httpd.conf
#ARG APACHE_HTDOCS=/var/www/localhost/htdocs
#ARG APACHE_CGIBIN=/var/www/localhost/cgi-bin
#ARG APACHE_HOST=localhost
#ARG APACHE_PORT=8888
#ARG APACHE_ADMIN=root@localhost.local
#ARG APACHE_PID_FILE=/var/run/apache2/apache2.pid
#ARG APACHE_LOG_DIR=/var/www/logs
#ARG APACHE_LOG_LEVEL=info

ARG MOTION_APACHE_CONF=/etc/apache2/httpd.conf
ARG MOTION_APACHE_HTDOCS=/var/www/localhost/htdocs
ARG MOTION_APACHE_CGIBIN=/var/www/localhost/cgi-bin
ARG MOTION_APACHE_HOST=localhost
ARG MOTION_APACHE_PORT=7999
ARG MOTION_APACHE_ADMIN=root@hassio.local

ENV MOTION_APACHE_CONF "${MOTION_APACHE_CONF}"
ENV MOTION_APACHE_HTDOCS "${MOTION_APACHE_HTDOCS}"
ENV MOTION_APACHE_CGIBIN "${MOTION_APACHE_CGIBIN}"
ENV MOTION_APACHE_HOST "${MOTION_APACHE_HOST}"
ENV MOTION_APACHE_PORT "${MOTION_APACHE_PORT}"
ENV MOTION_APACHE_ADMIN "${MOTION_APACHE_ADMIN}"

# Ports for motion (control and stream)
EXPOSE ${MOTION_APACHE_PORT}

EXPOSE 8080 8090

CMD [ "/usr/bin/run.sh" ]

# Build arugments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="MOTION" \
    io.hass.description="Motion package as addon w/ support for image classification" \ 
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"
