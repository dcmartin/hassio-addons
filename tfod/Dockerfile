
ARG BUILD_FROM=hassioaddons/base:2.0.0

FROM $BUILD_FROM

ENV LANG C.UTF-8

###
### ALPINE LINUX ADD-ON
###

MAINTAINER dcmartin <github@dcmartin.com>

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN echo "@community http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN apk update

RUN apk add --no-cache \
  bc \
  coreutils \
  curl \
  dateutils \
  findutils \
  gawk \
  inotify-tools \
  jq \
  mosquitto-clients \
  python3 \
  tcsh@community

RUN apk add libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev
RUN apk add libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
RUN apk add libxvidcore-dev libx264-dev
RUN apk add qt4-dev-tools

RUN mkdir /tf \
  && cd /tf \
  && wget https://github.com/lhelontra/tensorflow-on-arm/releases/download/v1.9.0/tensorflow-1.9.0-cp35-none-linux_armv7l.whl \
  && pip3 install /home/pi/tf/tensorflow-1.8.0-cp35-none-linux_armv7l.whl \
  && pip3 install pillow lxml jupyter matplotlib cython \
  && apk add python-tk \
  && pip3 install opencv-python

RUN apk add autoconf automake libtool curl \
  && wget https://github.com/google/protobuf/releases/download/v3.5.1/protobuf-all-3.5.1.tar.gz \
  && tar -zxvf protobuf-all-3.5.1.tar.gz \
  && cd protobuf-3.5.1 \
  && ./configure && make && make check && make install

RUN cd python \
  && export LD_LIBRARY_PATH=../src/.libs \
  && python3 setup.py build --cpp_implementation \
  && python3 setup.py test --cpp_implementation \
  && python3 setup.py install --cpp_implementation \
  && export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=cpp \
  && export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION_VERSION=3 \
  && ldconfig

ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION cpp
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION_VERSION 3

RUN mkdir /tensorflow && cd /tensorflow \
  && git clone --recurse-submodules https://github.com/tensorflow/models.git \
  && export PYTHONPATH=$PYTHONPATH:/tensorflow/models/research:/tensorflow/models/research/slim \
  && cd /tensorflow/models/research \
  && protoc object_detection/protos/*.proto --python_out=.

RUN cd /tensorflow/models/research/object_detection \
  && wget http://download.tensorflow.org/models/object_detection/ssdlite_mobilenet_v2_coco_2018_05_09.tar.gz \
  && tar -xzvf ssdlite_mobilenet_v2_coco_2018_05_09.tar.gz \
  && wget https://raw.githubusercontent.com/EdjeElectronics/TensorFlow-Object-Detection-on-the-Raspberry-Pi/master/Object_detection_picamera.py

# environment
ENV CONFIG_PATH /data/options.json

CMD [ "/usr/local/bin/run.sh" ]

# Build arugments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="AGEATHOME" \
    io.hass.description="AgeAtHome cognitive assistant" \ 
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"
