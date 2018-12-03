ARG BUILD_FROM=hassioaddons/ubuntu-base:2.2.0
# hadolint ignore=DL3006
FROM $BUILD_FROM

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# setup base system
ARG BUILD_ARCH=amd64

RUN apt-get update \
  && apt-get install -y \
    mosquitto-clients \
    tcsh \
    dateutils \
    bc \
    keychain \
    expect \
    nmap \
    apache2 \
    apache2-utils \
  \
  && ARCH="${BUILD_ARCH}" \
  && if [ "${BUILD_ARCH}" = "aarch64" ]; then ARCH="arm64"; fi \
  \
  && HORIZON_CLI="2.20.0" \
  && HORIZON_URL="http://pkg.bluehorizon.network/linux/ubuntu/pool/main/h/horizon/horizon-cli" \
  && HORIZON_PKG="${HORIZON_URL}_${HORIZON_CLI}~ppa~ubuntu.xenial_${ARCH}.deb" \
  && curl -fsSL -o /tmp/horizon-cli.deb  "${HORIZON_PKG}" \
  && dpkg --install /tmp/horizon-cli.deb \
  && rm -fr \
      /tmp/* \
      /var/{cache,log}/* \
      /var/lib/apt/lists/*

## APACHE

ARG APACHE_CONF=/etc/apache2/apache.conf
ARG APACHE_HTDOCS=/var/www/localhost/htdocs
ARG APACHE_CGIBIN=/var/www/localhost/cgi-bin
ARG APACHE_PORT=9999
ARG APACHE_COMMAND=apache2
ARG APACHE_LOG_DIR=/var/log
ARG APACHE_RUN_DIR=/run/apache2
ARG APACHE_RUN_USER=nobody
ARG APACHE_RUN_GROUP=nogroup

ENV APACHE_CONF "${APACHE_CONF}"
ENV APACHE_HTDOCS "${APACHE_HTDOCS}"
ENV APACHE_CGIBIN "${APACHE_CGIBIN}"
ENV APACHE_PORT "${APACHE_PORT}"
ENV APACHE_COMMAND "${APACHE_COMMAND}"
ENV APACHE_LOG_DIR "${APACHE_LOG_DIR}"
ENV APACHE_RUN_DIR "${APACHE_RUN_DIR}"
ENV APACHE_RUN_USER "${APACHE_RUN_USER}"
ENV APACHE_RUN_GROUP "${APACHE_RUN_GROUP}"

# Ports for motion (control and stream)
EXPOSE ${HORIZON_APACHE_PORT}

# Copy root filesystem
COPY rootfs /

CMD ["/usr/bin/run.sh"]

# Build arguments
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="horizon" \
    io.hass.description="Horizon addon base" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>" \
    org.label-schema.description="Base addon for horizon" \
    org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.name="horizon" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.url="https://addons.community" \
    org.label-schema.usage="https://github.com/dcmartin/hassio-addons/horizon/tree/master/README.md" \
    org.label-schema.vcs-ref=${BUILD_REF} \
    org.label-schema.vcs-url="https://github.com/dcmartin/hassio-addons/horizon" \
    org.label-schema.vendor="DCMARTIN"
