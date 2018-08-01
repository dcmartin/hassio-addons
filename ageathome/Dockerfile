
ARG BUILD_FROM=hassioaddons/base:2.0.0

FROM $BUILD_FROM

ENV LANG C.UTF-8

###
### ALPINE LINUX ADD-ON
###

MAINTAINER dcmartin <github@dcmartin.com>

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN echo "@community http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN apk update

RUN apk add --no-cache \
  apache2 \
  bc \
  coreutils \
  curl \
  dateutils \
  findutils \
  gawk \
  imagemagick \
  inotify-tools \
  jq \
  mosquitto-clients \
  python3 \
  tcsh@community

RUN apk add --update \
    python \
    python-dev \
    py-pip \
    build-base \
  && pip install --upgrade pip
  && pip install --upgrade setuptools
  && pip install --upgrade csvkit --ignore-installed six
  && rm -rf /var/cache/apk/*

# environment
ENV CONFIG_PATH /data/options.json

CMD [ "/usr/local/bin/run.sh" ]

# Build arugments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="AGEATHOME" \
    io.hass.description="AgeAtHome cognitive assistant" \ 
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"

# variables
ARG AAHDIR=/var/lib/age-at-home 
ARG CREDIR=/usr/local/etc

# environment
ENV DIGITS_HOST 192.168.1.40:32769
ENV CAMERA_IMAGE_WIDTH 640
ENV CAMERA_IMAGE_HEIGHT 480
ENV MODEL_IMAGE_WIDTH 224
ENV MODEL_IMAGE_HEIGHT 224
ENV CAMERA_MODEL_TRANSFORM CROP
ENV TMP /tmp
ENV AAHDIR ${AAHDIR}
ENV CREDENTIALS ${CREDIR}

# temporary files & credentials
RUN if [ ! -d "${AAHDIR}" ]; then mkdir -p "${AAHDIR}" && chgrp daemon "${AAHDIR}" && chmod 770 "${AAHDIR}"; fi

RUN if [ ! -d "${CREDIR}" ]; then mkdir -p "${CREDIR}" && chgrp daemon "${CREDIR}" && chmod 550 "${CREDIR}"; fi
# credentials
COPY ./.cloudant_url ${CREDIR}
RUN chmod 444 ${CREDIR}/.cloudant_url
COPY ./.watson.visual-recognition.json ${CREDIR}
RUN chmod 444 ${CREDIR}/.watson.visual-recognition.json
COPY ./.ftp_url ${CREDIR}
RUN chmod 444 ${CREDIR}/.ftp_url

# html
COPY ./public/ /usr/local/apache2/htdocs/

# cgi
COPY ./cgi/aah-*.csh /usr/local/apache2/cgi-bin/
COPY ./cgi/aah-*.cgi /usr/local/apache2/cgi-bin/
COPY ./cgi/aah-*.bash /usr/local/apache2/cgi-bin/

# httpd
COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf

EXPOSE 80

