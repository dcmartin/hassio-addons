ARG BUILD_FROM=hassioaddons/base-amd64:1.4.2

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN apk add --no-cache python3
RUN apk add --no-cache mosquitto-clients
RUN apk add --no-cache jq
RUN apk add --no-cache tcsh

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk update
RUN apk add motion@testing

# Copy "motion" scripts 
COPY *.sh /usr/local/bin/
COPY motion.conf /etc/motion/motion.conf

# Ports for motion (control and stream)
EXPOSE 8080 8081 8000

CMD [ "/usr/local/bin/run.sh" ]
