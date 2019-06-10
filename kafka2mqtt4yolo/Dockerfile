ARG BUILD_FROM=hassioaddons/ubuntu-base:2.2.0

# hadolint ignore=DL3006
FROM $BUILD_FROM

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# setup base system
ARG BUILD_ARCH=amd64

RUN apt-get update \
  && apt-get install -y kafkacat mosquitto-clients \
  \
  && rm -fr \
      /tmp/* \
      /var/{cache,log}/* \
      /var/lib/apt/lists/*

# Copy root filesystem
COPY rootfs /

CMD ["/usr/bin/run.sh"]

# Build arguments
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="kafka2mqtt4yolo" \
    io.hass.description="Relay Kafka messages to MQTT broker for YOLO" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>" \
    org.label-schema.description="Relay Kafka messages to MQTT broker for YOLO" \
    org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.name="kafka2mqtt4yolo" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.url="https://addons.community" \
    org.label-schema.usage="https://github.com/dcmartin/hassio-addons/kafka2mqtt4yolo/tree/master/README.md" \
    org.label-schema.vcs-ref=${BUILD_REF} \
    org.label-schema.vcs-url="https://github.com/dcmartin/hassio-addons/kafka2mqtt4yolo" \
    org.label-schema.vendor="DCMARTIN"
