ARG BUILD_FROM=hassioaddons/ubuntu-base:2.2.0
# hadolint ignore=DL3006
FROM $BUILD_FROM

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# setup base system
ARG BUILD_ARCH=amd64

ENV LANG C.UTF-8

ENV HZN_APT_REPO=testing
ENV HZN_APT_LIST=/etc/apt/sources.list.d/bluehorizon.list
ENV HZN_PUBLICKEY_URL=http://pkg.bluehorizon.network/bluehorizon.network-public.key


RUN apt-get update \
  && apt-get install -y --no-install-recommends \
      jq \
      curl \
  \
  && ARCH="${BUILD_ARCH}" \
  && if [ "${BUILD_ARCH}" = "aarch64" ]; then ARCH="arm64"; fi \
  \
  && HORIZON_CLI="2.18.1" \
  && curl -J -L -o /tmp/horizon-cli.deb "http://pkg.bluehorizon.network/linux/ubuntu/pool/main/h/horizon/horizon-cli_${HORIZON_CLI}~ppa~ubuntu.xenial_${ARCH}.deb" \
  && dpkg --install /tmp/horizon-cli.deb \
  && rm -fr \
      /tmp/* \
      /var/{cache,log}/* \
      /var/lib/apt/lists/*

#  \
#  && curl -fsFL "${HZN_PUBLICKEY_URL}" | apt-key add - \
#  && echo "deb [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}" \
#  && echo "deb-src [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}" \
#  \
#  && apt-get update -y \
#  && apt-get install -y horizon-cli

# the pattern we expect to run
ENV HZN_PATTERN_ORG_ID="IBM"
ENV HZN_PATTERN_ID="cpu2msghub"
ENV HZN_PATTERN_URL="https://github.com/open-horizon/examples/wiki/service-cpu2msghub"

# ENV CONFIG_PATH /data/options.json

ARG LOCAL_BIN=/usr/local/bin
RUN mkdir -p "${LOCAL_BIN}"
COPY *.sh "${LOCAL_BIN}"/
RUN chmod 755 "${LOCAL_BIN}"/*.sh

CMD [ "/usr/local/bin/run.sh" ]

# Build arguments
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="cpu2msghub" \
    io.hass.description="Example Horizon-based addon to share CPU statistics" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"
