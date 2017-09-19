FROM %%BASE_IMAGE%%

ENV LANG C.UTF-8

#FROM ubuntu:16.04

#FROM arm64/armhf-ubuntu:16.04

MAINTAINER dyec@us.ibm.com

# Install build prereqs

RUN apt-get update && apt-get install -y \ build-essential \ cmake \ curl \ git \ apt-utils \ libpng12-dev \ alsa-utils \ python \ python-pip \ python2.7-dev \ gettext \ libcurl4-openssl-dev \ libssl-dev \ unzip \ wget \ vim

## Grab self code

RUN mkdir -p /root/src/watson-intu

#WORKDIR /root/src/watson-intu

RUN git clone --branch develop --recursive https://github.com/watson-intu/self.git /root/src/watson-intu/self

WORKDIR /root/src/watson-intu/self

## Clone/build wiringPi

RUN git clone git://git.drogon.net/wiringPi /root/src/wiringPi

WORKDIR /root/src/wiringPi

COPY build /root/src/wiringPi/build

RUN ./build

## Install self prereqs

RUN pip install --upgrade pip

RUN pip install qibuild numpy

RUN apt-get install -y libopencv-dev python-opencv libboost-all-dev

# bypass prompts with libpcl-dev

RUN export DEBIAN_FRONTEND=noninteractive

RUN apt-get install -yq libpcl-dev

## Build Self

WORKDIR /root/src/watson-intu/self

# use the tc_install.sh file, commented out raspi boost libs (wrong format)

COPY tc_install.sh /root/src/watson-intu/self/scripts/tc_install.sh

RUN mkdir -p /root/src/watson-intu/self/packages

# Skipping this file for now, using raspi build scripts for arm64

#COPY naoqi-sdk-2.1.4.13-linux64.zip /root/src/watson-intu/self/packages/

#RUN chmod +x scripts/build_linux.sh

RUN chmod +x scripts/build_raspi.sh

#RUN scripts/tc_clean.sh

RUN scripts/build_raspi.sh

#EXPOSE 9443

# Copy data for add-on
COPY run.sh /
RUN chmod a+x /run.sh
CMD [ "/run.sh" ]

