#!/bin/bash
echo "+++ BEGIN: $0: $*" $(date) >&2

EVENT=$1
IMAGE_FILE=$2
IMAGE_TYPE=$3
MOTION_MIDX=$4
MOTION_MIDY=$5
MOTION_WIDTH=$6
MOTION_HEIGHT=$7

/bin/echo "$0 -- ${EVENT} ${IMAGE_FILE} ${MOTION_MIDX} ${MOTION_MIDY} ${MOTION_WIDTH} ${MOTION_HEIGHT}"

echo "+++ END: $0: $*" $(date) >&2
