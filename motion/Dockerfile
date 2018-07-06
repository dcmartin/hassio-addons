ARG BUILD_FROM=hassioaddons/base-amd64:1.4.2

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk update

RUN apk add --no-cache python3 mosquitto-clients jq curl motion@testing

# Copy "motion" scripts 
COPY *.sh /usr/local/bin/
COPY motion.conf /etc/motion/motion.conf

# Ports for motion (control and stream)
EXPOSE 8000 8080 8081 8082 8083 8084

# environment
ENV CONFIG_PATH /data/options.json
ENV MOTION_CONF /etc/motion/motion.conf

CMD [ "/usr/local/bin/run.sh" ]
