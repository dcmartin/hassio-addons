ARG BUILD_FROM=hassioaddons/base:2.0.0

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN echo "@community http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN apk update

RUN apk add --no-cache coreutils python3 mosquitto-clients jq bc curl dateutils findutils imagemagick tcsh@community motion@testing

# args
ARG MOTION_CONF=/etc/motion/motion.conf 
ARG LOCAL_BIN=/usr/local/bin

# environment
ENV CONFIG_PATH /data/options.json
ENV MOTION_CONF "${MOTION_CONF}"

# Copy "motion" scripts 
COPY motion.conf "${MOTION_CONF}"
RUN mkdir -p "{LOCAL_BIN}" 
COPY *.sh "${LOCAL_BIN}"/
RUN chmod 755 "${LOCAL_BIN}"/*.sh

# Ports for motion (control and stream)
EXPOSE 8000 
EXPOSE 8080 8081 8082 8083 8084 8085 8086 8087 8088 8089 8090

# mount -t tmpfs -o size=512m tmpfs /mnt/ramdisk

CMD [ "/usr/local/bin/run.sh" ]

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
