ARG BUILD_FROM=hassioaddons/base-aarch64:5.0.1

FROM $BUILD_FROM

ENV LANG C.UTF-8

CMD [ "/usr/bin/run.sh" ]

# Build arugments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="motion-local" \
    io.hass.description="Motion addon with local camera support" \ 
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"
