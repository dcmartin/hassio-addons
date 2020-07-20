ARG BUILD_FROM=${BUILD_FROM}

FROM $BUILD_FROM as build

ARG BUILD_ARCH=amd64

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# setup base system
RUN apt update -qq -y && apt upgrade -qq -y

# minimum
RUN apt install -qq -y \
  ca-certificates \
  curl \
  apt-utils \
  jq

# python3.7
RUN apt install -qq -y \
  build-essential \
  zlib1g-dev \
  libncurses5-dev \
  libgdbm-dev \
  libnss3-dev \
  libssl-dev \
  libreadline-dev \
  libffi-dev \
  libsqlite3-dev \
  libbz2-dev

RUN \
  cd /tmp \
  && \
  curl -sSL https://www.python.org/ftp/python/3.7.7/Python-3.7.7.tgz -o python.tgz \
  && \
  tar xzf python.tgz \
  && \
  cd Python-3.7.7 \
  && \
  ./configure --enable-optimizations \
  && \
  make -j 4 \
  && \
  make install

# python upgrade
RUN python3 --version

# maximum
RUN apt update -qq -y && apt install -qq -y \
  libgstreamer1.0-0 \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav gstreamer1.0-doc \
  gstreamer1.0-tools gstreamer1.0-x \
  gstreamer1.0-alsa \
  gstreamer1.0-gl gstreamer1.0-gtk3 \
  gstreamer1.0-pulseaudio \
  python3-gst-1.0 \
  python3-gi \
  python3-numpy \
  libjpeg-dev \
  zlib1g-dev \
  pkg-config \
  libavdevice-dev \
  libavfilter-dev \
  libopus-dev \
  libvpx-dev \
  libsrtp2-dev \
  procps \
  udev \
  libusb-1.0-0 \
  libc++1 \
  libc++abi1 \
  libunwind8 \
  libgcc1 \
  git \
  python3-pip \
  libx264-dev \
  libhdf5-dev \
  software-properties-common

## FFMPEG v4

RUN add-apt-repository ppa:jonathonf/ffmpeg-4

RUN apt update -qq -y \
  && \
  apt install -qq -y ffmpeg \
  && \
  apt upgrade -qq -y

# cleanup
RUN apt clean -qq -y && apt autoremove -qq -y && \
      rm -fr \
      /tmp/* \
      /var/{cache,log}/* \
      /var/lib/apt/lists/*

FROM build as prereqs

# pip
RUN pip3 install --upgrade pip

# wheel
RUN pip3 install --upgrade wheel

# gi
RUN apt update -qq -y && apt install -qq -y libcairo2-dev libgirepository1.0-dev
RUN pip3 install --upgrade pycairo
RUN pip3 install --upgrade PyGObject

# cython
RUN pip3 install --upgrade cython

# h5py
RUN pip3 install --upgrade h5py

# aiortc
RUN pip3 install --upgrade aiortc

# peerjs
RUN pip3 install --upgrade peerjs

RUN pip3 install 'Click>=7.0'
RUN pip3 install 'Flask>=1.0.2'
RUN pip3 install 'Jinja2>=2.10.1'
RUN pip3 install 'Pillow>=5.4.1'
RUN pip3 install 'PyYAML>=5.1.2'
RUN pip3 install 'Werkzeug>=0.15.3'
RUN pip3 install 'absl-py>=0.7.1'
RUN pip3 install 'appdirs>=1.4.3'
RUN pip3 install 'asn1crypto>=0.24.0'
RUN pip3 install 'astor>=0.8.0'
RUN pip3 install 'asttokens>=1.1.13'
RUN pip3 install 'beautifulsoup4>=4.7.1'
RUN pip3 install 'blinker>=1.4'
RUN pip3 install 'certifi>=2018.8.24'
RUN pip3 install 'chardet>=3.0.4'
RUN pip3 install 'cookies>=2.2.1'
RUN pip3 install 'cryptography>=2.8'
RUN pip3 install 'decorator>=4.3.0'
RUN pip3 install 'entrypoints>=0.3'
RUN pip3 install 'flask-cors'
RUN pip3 install 'gast>=0.2.2'
RUN pip3 install 'google-pasta>=0.1.7'
RUN pip3 install 'h5py>=2.9.0'
RUN pip3 install 'idna>=2.6'
RUN pip3 install 'itsdangerous>=0.24'
RUN pip3 install 'numpy>=1.16.2'
RUN pip3 install 'oauthlib>=2.1.0'
RUN pip3 install 'pyOpenSSL>=19.0.0'
RUN pip3 install 'requests-oauthlib>=1.0.0'
RUN pip3 install 'requests>=2.21.0'
RUN pip3 install 'responses>=0.9.0'
RUN pip3 install 'simplegeneric>=0.8.1'
RUN pip3 install 'simplejson>=3.16.0'
RUN pip3 install 'webencodings>=0.5.1'
RUN pip3 install 'inotify-simple'
RUN pip3 install 'portalocker>=1.4.0'
RUN pip3 install 'concurrent-log-handler'

FROM prereqs as tflite

### TPU

# tflite
RUN ARCH=$(uname -m) && pip3 install https://dl.google.com/coral/python/tflite_runtime-1.14.0-cp37-cp37m-linux_${ARCH}.whl

RUN pip3 show tflite-runtime

# get TPU
RUN  curl -sSL https://dl.google.com/coral/edgetpu_api/edgetpu_api_latest.tar.gz -o /tmp/edgetpu_api.tar.gz \
  && \
  cd /tmp \
  && \
  tar xzf edgetpu_api.tar.gz

RUN \
  ARCH=$(uname -m) \
  && \
  if [ "${ARCH}" = 'armv7l' ]; then \
    LIBEDGETPU_SUFFIX=arm32 HOST_GNU_TYPE=arm-linux-gnueabihf; \
  elif [ "${ARCH}" = 'x86_64' ]; then \
    LIBEDGETPU_SUFFIX=x86_64 HOST_GNU_TYPE=x86_64-linux-gnu; \
  elif [ "${ARCH}" = 'aarch64' ]; then \
    LIBEDGETPU_SUFFIX=arm64 HOST_GNU_TYPE=aarch64-linux-gnu; \
  fi \
  && \
  if [ ! -z "${EDGETPU_THROTTLE:-}" ]; then \
    LIBEDGETPU_SRC="/tmp/edgetpu_api/libedgetpu/libedgetpu_${LIBEDGETPU_SUFFIX}_throttled.so"; \
  else \
    LIBEDGETPU_SRC="/tmp/edgetpu_api/libedgetpu/libedgetpu_${LIBEDGETPU_SUFFIX}.so"; \
  fi \
  && \
  LIBEDGETPU_DST="/usr/lib/${HOST_GNU_TYPE}/libedgetpu.so.1.0" \
    LIBEDGETPU_SRC="/tmp/edgetpu_api/libedgetpu/libedgetpu_${LIBEDGETPU_SUFFIX}_throttled.so" \
    LIBEDGETPU_DST="/usr/lib/${HOST_GNU_TYPE}/libedgetpu.so.1.0" \
  && \
  cp "${LIBEDGETPU_SRC}" "${LIBEDGETPU_DST}" \
  && \
  ldconfig

RUN \
    mkdir -p /etc/udev/rules.d \
    && \
    cp /tmp/edgetpu_api/99-edgetpu-accelerator.rules /etc/udev/rules.d/99-edgetpu-accelerator.rules

#RUN udevadm control --reload-rules

#RUN udevadm trigger

# Python API.
RUN pip3 install --no-deps /tmp/edgetpu_api/edgetpu-2.11.1-py3-none-any.whl

# cleanup
RUN apt clean -qq -y && apt autoremove -qq -y && \
      rm -fr \
      /tmp/* \
      /var/{cache,log}/* \
      /var/lib/apt/lists/*

FROM tflite

# define reality
ARG AMBIANIC_EDGE=/opt/ambianic-edge
ENV AMBIANIC_EDGE ${AMBIANIC_EDGE}

# the meat
RUN mkdir -p ${AMBIANIC_EDGE} \
      && \
      cd ${AMBIANIC_EDGE} \
      && \
      git clone http://github.com/dcmartin/ambianic-edge.git .

RUN cd ${AMBIANIC_EDGE} \
    && \
    pip3 install -r build/requirements.txt \
    && \
    pip3 install -e src

# Copy root filesystem
COPY rootfs /

EXPOSE 8778

CMD ["/usr/bin/run.sh"]

# Build arguments
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="ambianic" \
    io.hass.description="Ambianic Edge" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>" \
    org.label-schema.description="Ambianic Edge" \
    org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.name="cpu2msghub" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.url="https://addons.community" \
    org.label-schema.usage="https://github.com/dcmartin/hassio-addons/ambianic/tree/master/README.md" \
    org.label-schema.vcs-ref=${BUILD_REF} \
    org.label-schema.vcs-url="https://github.com/dcmartin/hassio-addons/ambianic" \
    org.label-schema.vendor="DCMARTIN"
