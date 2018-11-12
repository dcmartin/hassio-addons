ARG BUILD_FROM=hassioaddons/base:2.3.0

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN apk add --no-cache \
  apache2 \
  apache2-utils \
  bc \
  coreutils \
  curl \
  dateutils \
  findutils \
  ffmpeg@edge \
  motion@edge \
  gawk \
  imagemagick \
  inotify-tools \
  jq \
  mosquitto-clients \
  python3 \
  tcsh \
  git

## CVSKIT

#RUN apk add --update \
#    python \
#    python-dev \
#    py-pip \
#    build-base
#
#RUN pip install --upgrade pip \
#    && pip install --upgrade setuptools \
#    && pip install --upgrade csvkit --ignore-installed six \
#    && rm -rf /var/cache/apk/*


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
