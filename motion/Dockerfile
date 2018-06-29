ARG BUILD_FROM

FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

RUN apk update

RUN apk add motion@testing

# REQUIRED: packages
RUN apk add mosquitto-clients jq

# Copy "motion" scripts 
COPY scripts/* /usr/local/bin/
COPY motion.conf /etc/motion/motion.conf

# Ports for motion (control and stream)
EXPOSE 8080 8081

# set working directory
WORKDIR /var/lib/motion

# Copy data for add-on
ARG DESTDIR "/usr/local/bin"
COPY run.sh ${DESTDIR}
RUN chmod a+x ${DESTDIR}/run.sh
CMD [ "${DESTDIR}/run.sh" ]


