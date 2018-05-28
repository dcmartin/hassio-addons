ARG BUILD_FROM

FROM $BUILD_FROM

ENV LANG C.UTF-8

# PYTHON EXAMPLE
RUN apk add --no-cache python3
WORKDIR /data


# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
