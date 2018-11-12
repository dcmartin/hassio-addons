#!/bin/bash
echo "+++ BEGIN: ${0##*/}: $*" $(date) >& /dev/stderr

DEBUG=true
# VERBOSE=true

# %Y = year, %m = month, %d = date,
# %H = hour, %M = minute, %S = second,
# %v = event, %q = frame number, %t = thread (camera) number,
# %D = changed pixels, %N = noise level,
# %i and %J = width and height of motion area,
# %K and %L = X and Y coordinates of motion center
# %C = value defined by text_event
# %f = filename with full path
# %n = number indicating filetype
# %$ = camera name

# on_motion_detected on_motion_detect.sh %$ %v %Y %m %d %H %M %S


# get arguments
CAMERA_NAME="${1}"
EVENT="${2}"
YEAR="${3}"
MONTH="${4}"
DAY="${5}"
HOUR="${6}"
MINUTE="${7}"
SECOND="${8}"

echo "+++ END: ${0##*/}: $*" $(date) >& /dev/stderr
