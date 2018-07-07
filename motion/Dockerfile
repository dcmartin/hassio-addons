ARG BUILD_FROM=hassioaddons/base:2.0.0

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk update

RUN apk add --no-cache coreutils python3 mosquitto-clients jq curl motion@testing

# 
ARG MOTION_CONF=/etc/motion/motion.conf 
ARG LOCAL_BIN=/usr/local/bin

# environment
ENV CONFIG_PATH /data/options.json
ENV MOTION_CONF "${MOTION_CONF}"


# Copy "motion" scripts 
COPY motion.conf "${MOTION_CONF}"
COPY *.sh "${LOCAL_BIN}"
RUN chmod 755 "${LOCAL_BIN}"/*.sh

# Ports for motion (control and stream)
EXPOSE 8000 8080 8081 8082 8083 8084

CMD [ "${LOCAL_BIN}/run.sh" ]

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
