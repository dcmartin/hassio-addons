ARG BUILD_FROM=hassioaddons/base:2.0.0

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk update

RUN apk add --no-cache coreutils python3 mosquitto-clients jq curl motion@testing

# Copy "motion" scripts 
COPY *.sh /usr/local/bin/
COPY motion.conf /etc/motion/motion.conf

# Ports for motion (control and stream)
EXPOSE 8000 8080 8081 8082 8083 8084

# environment
ENV CONFIG_PATH /data/options.json
ENV MOTION_CONF /etc/motion/motion.conf

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
