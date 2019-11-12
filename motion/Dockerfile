ARG BUILD_FROM=hassioaddons/base

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN apk add --no-cache \
  bc \
  coreutils \
  curl \
  dateutils \
  findutils \
  gawk \
  jq \
  tcsh \
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
  ffmpeg@edge \
  motion@edge

# environment
ENV CONFIG_PATH /data/options.json
ENV MOTION_CONF /etc/motion/motion.conf

# Copy rootts
COPY rootfs /

## APACHE

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

EXPOSE 8000 8080 8081 8082 
EXPOSE 8090 8091 8092 8093 8094 8095 8096 8097 8099 8099
EXPOSE 8100 8101 8102 8103 8104 8105 8106 8107 8109 8109
EXPOSE 8110 8111 8112 8113 8114 8115 8116 8117 8119 8119

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
