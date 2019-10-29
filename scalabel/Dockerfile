ARG BUILD_FROM=hassioaddons/base:2.0.1
  
FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN echo "@community http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN apk update

RUN apk add --no-cache \
  bc \
  jq \
  git \
  curl \
  coreutils \
  dateutils \
  findutils \
  inotify-tools \
  tcsh@community

# Ports for motion (control and stream)
EXPOSE 8686

# RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apk add nodejs npm go

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN cd /
RUN git clone "https://github.com/ucbdrive/scalabel.git"

RUN npm install -g express
RUN npm init -y
RUN npm install --save-dev webpack webpack-cli copy-webpack-plugin

RUN go get github.com/aws/aws-sdk-go github.com/mitchellh/mapstructure gopkg.in/yaml.v2 github.com/satori/go.uuid

RUN cd scalabel && mkdir -p data && npx webpack --config /scalabel/webpack.config.js --mode=production && go build -i -o $GOPATH/bin/scalabel ./server/go
CMD [ "$GOPATH/bin/scalabel --config app/config/default_config.yml" ]

# Build arugments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="SCALABEL" \
    io.hass.description="UCB DeepDrive scalabel.ai" \ 
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="David C Martin <github@dcmartin.com>"
