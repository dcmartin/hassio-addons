ARG BUILD_FROM=hassioaddons/ubuntu-base:latest

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN apt-get update -y
RUN apt-get install -y apt-utils coreutils gnupg

# args
ARG LOCAL_BIN=/usr/local/bin

RUN mkdir -p "${LOCAL_BIN}" 
COPY *.sh "${LOCAL_BIN}"/
RUN chmod 755 "${LOCAL_BIN}"/*.sh

ARG BUILD_ARCH=amd64

ENV  HZN_APT_REPO=testing
ENV  HZN_APT_LIST=/etc/apt/sources.list.d/bluehorizon.list
ENV  HZN_PUBLICKEY_URL=http://pkg.bluehorizon.network/bluehorizon.network-public.key

RUN curl -fsSL "${HZN_PUBLICKEY_URL}" | apt-key add -
RUN echo "deb [arch=${BUILD_ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}"
RUN echo "deb-src [arch=${BUILD_ARCH}] http://pkg.bluehorizon.network/linux/ubuntu xenial-${HZN_APT_REPO} main" >> "${HZN_APT_LIST}"
RUN apt-get update -y
RUN apt-get install -y horizon-cli

#{
#  "id": "cpu2msghub",
#  "org": "IBM",
#  "url": "https://github.com/open-horizon/examples/wiki/service-cpu2msghub",
#  "services": [
#    {
#      "id": "cpu2msghub",
#      "org": "IBM",
#      "url": "https://github.com/open-horizon/examples/wiki/service-cpu"
#    },
#    {
#      "id": "gps2msghub",
#      "org": "IBM",
#      "url": "https://github.com/open-horizon/examples/wiki/service-gps"
#    }
#  ]
#}

ENV HZN_PATTERN='{"id":"cpu2msghub","org":"IBM","url":"https://github.com/open-horizon/examples/wiki/service-cpu2msghub","services":[{"id":"cpu2msghub","org":"IBM","url":"https://github.com/open-horizon/examples/wiki/service-cpu"},{"id":"gps2msghub","org":"IBM","url":"https://github.com/open-horizon/examples/wiki/service-gps"}]}'

# the data exchange we expect to use
ENV  HZN_EXCHANGE_URL='https://stg-edge-cluster.us-south.containers.appdomain.cloud/v1'

# environment
ENV CONFIG_PATH /data/options.json

CMD [ "/usr/local/bin/run.sh" ]

# Build arugments
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="cpu2msghub" \
    io.hass.description="Example open horizon addon to share CPU && GPS" \ 
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"
