FROM %%BASE_IMAGE%%

ENV LANG C.UTF-8

RUN apt-get update && apt-get -y install motion

RUN apt-get install -q -y --no-install-recommends \
    apt-utils \
    csh \
    git \
    make \
    tcsh \
    bc \
    gawk \
    imagemagick \
    curl \
    unzip \
    vsftpd \
    gcc

RUN apt-get install -q -y --no-install-recommends \
    bison \
    alsa-base \
    alsa-utils \
    libasound2-dev \
    libtool \
    sox \
    autoconf \
    automake

#
# JQ v 1.5
#
RUN cd /usr/src \
        && curl -L "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-1.5.tar.gz" > jq.gz \
        && tar xzvf jq.gz \
        && cd jq-1.5 \
        && autoreconf -i \
        && ./configure \
        && make \
        && make install \
        && make distclean

#
# VSFTPD
#
RUN echo "anon_root=/var/lib/motion" >> /etc/vsftpd.conf \
      && sed -i -e"s/^.*listen=.*$/listen=YES/" /etc/vsftpd.conf \
      && sed -i -e"s/^.*listen_ipv6=.*$/listen_ipv6=NO/" /etc/vsftpd.conf \
      && sed -i -e"s/^.*anonymous_enable=.*$/anonymous_enable=YES/" /etc/vsftpd.conf

# Copy "motion" scripts 
COPY script/* /usr/local/bin/
COPY motion.conf /etc/motion/motion.conf

# Ports for motion (control and stream)
EXPOSE 8080 8081

# Create volume to store images & videos
VOLUME ["/var/lib/motion"]

# set working directory
WORKDIR /var/lib/motion

# invoke motion detection script (NOT as daemon; re-direct logging to STDERR)
CMD [ "/usr/local/bin/run.sh" ]

