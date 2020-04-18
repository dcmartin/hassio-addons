#!/bin/bash

find_rtsp()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local result
  echo ${result:-null}
}

###
### MAIN
###

if [ ! -z "${1}" ]; then
  pidfile="${2:-/tmp/${0##*/}.pid}"
  mkdir -p ${pidfile%/*}
  if [ ! -s ${pidfile} ]; then
    echo "$$" > "${pidfile}"
    if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- initiating; pidfile: ${pidfile}; PID: " $(cat ${pidfile}) &> /dev/stderr; fi
    temp=$(mktemp -t "${0##*/}-XXXXXX")
    echo '{"rtsp":'$(find-rtsp)'}' | tee ${temp} | jq -c '.'
    if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- produced output; output: " $(cat ${temp}) &> /dev/stderr; fi
    mv -f ${temp} ${1}
    rm -f ${pidfile}
  else
    echo "+++ WARN -- $0 $$ -- currently processing; pidfile: ${pidfile}; PID: " $(cat ${pidfile}) &> /dev/stderr
  fi
else
  echo "*** ERROR -- $0 $$ -- provide file name for output" &> /dev/stderr
  exit 1
fi
