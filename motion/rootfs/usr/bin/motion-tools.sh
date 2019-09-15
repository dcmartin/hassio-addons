#!/usr/bin/env bash

##
## DATEUTILS
##

if [ -e /usr/bin/dateutils.dconv ]; then
  dateconv=/usr/bin/dateutils.dconv
elif [ -e /usr/bin/dateconv ]; then
  dateconv=/usr/bin/dateconv
elif [ -e /usr/local/bin/dateconv ]; then
  dateconv=/usr/local/bin/dateconv
else
  exit 1
fi

##
## MQTT
##

mqtt_pub()
{
  hzn.log.trace "${FUNCNAME[0]}"

  if [ -z "${MQTT_DEVICE:-}" ]; then MQTT_DEVICE=$(hostname) && hzn.log.notice "MQTT_DEVICE unspecified; using hostname: ${MQTT_DEVICE}"; fi
  ARGS=${*}
  if [ ! -z "${ARGS}" ]; then
    if [ ! -z "${MQTT_USERNAME}" ]; then
      ARGS='-u '"${MQTT_USERNAME}"' '"${ARGS}"
    fi
    if [ ! -z "${MQTT_PASSWORD}" ]; then
      ARGS='-P '"${MQTT_PASSWORD}"' '"${ARGS}"
    fi
    hzn.log.debug "mosquitto_pub -i ${MQTT_DEVICE} -h ${MQTT_HOST} -p ${MQTT_PORT} ${ARGS}"
    mosquitto_pub -i "${MQTT_DEVICE}" -h "${MQTT_HOST}" -p "${MQTT_PORT}" ${ARGS}
  fi
}

##
## logging
##

MOTION_LEVEL_EMERG=0
MOTION_LEVEL_ALERT=1
MOTION_LEVEL_CRIT=2
MOTION_LEVEL_ERROR=3
MOTION_LEVEL_WARN=4
MOTION_LEVEL_NOTICE=5
MOTION_LEVEL_INFO=6
MOTION_LEVEL_DEBUG=7
MOTION_LEVEL_TRACE=8
MOTION_LEVEL_ALL=9
MOTION_LEVELS=(EMERGENCY ALERT CRITICAL ERROR WARNING NOTICE INFO DEBUG TRACE ALL)
MOTION_FORMAT_DEFAULT='[TIMESTAMP] LEVEL >>>'
MOTION_TIMESTAMP_DEFAULT='%FT%TZ'
MOTION_FORMAT="${MOTION_FORMAT:-${MOTION_FORMAT_DEFAULT}}"
MOTION_LEVEL="${MOTION_LEVEL:-${MOTION_LEVEL_INFO}}"
MOTION_TIMESTAMP_FORMAT="${MOTION_TIMESTAMP_FORMAT:-${MOTION_TIMESTAMP_DEFAULT}}"

# logging by level

hzn.log.emerg()
{ 
  hzn.log.logto ${MOTION_LEVEL_EMERG} "${*}"
}

hzn.log.alert()
{
  hzn.log.logto ${MOTION_LEVEL_ALERT} "${*}"
}

hzn.log.crit()
{
  hzn.log.logto ${MOTION_LEVEL_CRIT} "${*}"
}

hzn.log.error()
{
  hzn.log.logto ${MOTION_LEVEL_ERROR} "${*}"
}

hzn.log.warn()
{
  hzn.log.logto ${MOTION_LEVEL_WARN} "${*}"
}

hzn.log.notice()
{
  hzn.log.logto ${MOTION_LEVEL_NOTICE} "${*}"
}

hzn.log.info()
{
  hzn.log.logto ${MOTION_LEVEL_INFO} "${*}"
}

hzn.log.debug()
{
  hzn.log.logto ${MOTION_LEVEL_DEBUG} "${*}"
}

hzn.log.trace()
{
  hzn.log.logto ${MOTION_LEVEL_TRACE} "${*}"
}

hzn.log.level()
{
  case "${MOTION_LEVEL}" in
    emerg) LL=${MOTION_LEVEL_EMERG} ;;
    alert) LL=${MOTION_LEVEL_ALERT} ;;
    crit) LL=${MOTION_LEVEL_CRIT} ;;
    error) LL=${MOTION_LEVEL_ERROR} ;;
    warn) LL=${MOTION_LEVEL_WARN} ;;
    notice) LL=${MOTION_LEVEL_NOTICE} ;;
    info) LL=${MOTION_LEVEL_INFO} ;;
    debug) LL=${MOTION_LEVEL_DEBUG} ;;
    trace) LL=${MOTION_LEVEL_TRACE} ;;
    *) LL=${MOTION_LEVEL_ALL} ;;
  esac
  echo ${LL:-${MOTION_LEVEL_ALL}}
}

hzn.log.logto()
{
  local level="${1:-0}"
  local current=$(hzn.log.level)
  local exp='^[0-9]+$'

  if ! [[ ${level} =~ ${exp} ]] ; then
   echo "hzn.log.logto: error: level ${level} not a number ${FUNCNAME}" &> ${LOGTO}
   level=
  fi
  if ! [[ ${current} =~ ${exp} ]] ; then
   echo "hzn.log.logto: error: current ${current} not a number ${FUNCNAME}" &> ${LOGTO}
   current=
  fi
  if [ "${level:-0}" -le ${current:-9} ]; then
    message="${2:-}"
    timestamp=$(date -u +"${MOTION_TIMESTAMP_FORMAT}")
    output="${MOTION_FORMAT}"
    output=$(echo "${output}" | sed 's/TIMESTAMP/'${timestamp}'/')
    output=$(echo "${output}" | sed 's/LEVEL/'${MOTION_LEVELS[${level}]}'/')
    echo "${0##*/} $$ ${output} ${message}" &> ${LOGTO:-/dev/stderr}
  fi
}
