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

HZN_LEVEL_EMERG=0
HZN_LEVEL_ALERT=1
HZN_LEVEL_CRIT=2
HZN_LEVEL_ERROR=3
HZN_LEVEL_WARN=4
HZN_LEVEL_NOTICE=5
HZN_LEVEL_INFO=6
HZN_LEVEL_DEBUG=7
HZN_LEVEL_TRACE=8
HZN_LEVEL_ALL=9
HZN_LEVELS=(EMERGENCY ALERT CRITICAL ERROR WARNING NOTICE INFO DEBUG TRACE ALL)
HZN_FORMAT_DEFAULT='[TIMESTAMP] LEVEL >>>'
HZN_TIMESTAMP_DEFAULT='%FT%TZ'
HZN_FORMAT="${HZN_FORMAT:-${HZN_FORMAT_DEFAULT}}"
HZN_LEVEL="${HZN_LEVEL:-${HZN_LEVEL_INFO}}"
HZN_TIMESTAMP_FORMAT="${HZN_TIMESTAMP_FORMAT:-${HZN_TIMESTAMP_DEFAULT}}"

# logging by level

hzn.log.emerg()
{
  hzn.log.logto ${HZN_LEVEL_EMERG} "${*}"
}

hzn.log.alert()
{
  hzn.log.logto ${HZN_LEVEL_ALERT} "${*}"
}

hzn.log.crit()
{
  hzn.log.logto ${HZN_LEVEL_CRIT} "${*}"
}

hzn.log.error()
{
  hzn.log.logto ${HZN_LEVEL_ERROR} "${*}"
}

hzn.log.warn()
{
  hzn.log.logto ${HZN_LEVEL_WARN} "${*}"
}

hzn.log.notice()
{
  hzn.log.logto ${HZN_LEVEL_NOTICE} "${*}"
}

hzn.log.info()
{
  hzn.log.logto ${HZN_LEVEL_INFO} "${*}"
}

hzn.log.debug()
{
  hzn.log.logto ${HZN_LEVEL_DEBUG} "${*}"
}

hzn.log.trace()
{
  hzn.log.logto ${HZN_LEVEL_TRACE} "${*}"
}

hzn.log.level()
{
  case "${HZN_LEVEL}" in
    emerg) LL=${HZN_LEVEL_EMERG} ;;
    alert) LL=${HZN_LEVEL_ALERT} ;;
    crit) LL=${HZN_LEVEL_CRIT} ;;
    error) LL=${HZN_LEVEL_ERROR} ;;
    warn) LL=${HZN_LEVEL_WARN} ;;
    notice) LL=${HZN_LEVEL_NOTICE} ;;
    info) LL=${HZN_LEVEL_INFO} ;;
    debug) LL=${HZN_LEVEL_DEBUG} ;;
    trace) LL=${HZN_LEVEL_TRACE} ;;
    *) LL=${HZN_LEVEL_ALL} ;;
  esac
  echo ${LL:-${HZN_LEVEL_ALL}}
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
    timestamp=$(date -u +"${HZN_TIMESTAMP_FORMAT}")
    output="${HZN_FORMAT}"
    output=$(echo "${output}" | sed 's/TIMESTAMP/'${timestamp}'/')
    output=$(echo "${output}" | sed 's/LEVEL/'${HZN_LEVELS[${level}]}'/')
    echo "${output} ${message}" &> ${LOGTO:-/dev/stderr}
  fi
}
