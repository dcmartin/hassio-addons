#!/bin/bash

if [ $(arch) != "armv7l" ]; then
  echo "*** ERROR $0 $$ -- for RaspberryPi only"
  exit 1
fi

if [ $(whoami) != "root" ]; then
  echo "*** ERROR $0 $$ -- run as root"
  exit 1
fi

uhubctl -l 1-1 -p 2 -a 0
