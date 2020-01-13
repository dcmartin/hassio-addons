#!/usr/bin/env bash

###
### motion-tools.sh
###

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

###
### CONFIGURATION
###

motion.config.target_dir()
{
  motion.log.trace "${FUNCNAME[0]}"

  local file=$(motion.config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.motion.target_dir' ${file})
    motion.log.debug "configuration target_dir: ${result}"
  else
    motion.log.warn "no configuration JSON: ${file}"
  fi
  echo "${result:-}"
}

motion.config.share_dir()
{
  motion.log.trace "${FUNCNAME[0]}"

  local file=$(motion.config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.share_dir' ${file})
  else
    motion.log.warn "no configuration file"
  fi
  echo "${result:-}"
}

motion.config.group()
{
  motion.log.trace "${FUNCNAME[0]}"

  local file=$(motion.config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.group' ${file})
  else
    motion.log.warn "no configuration file"
  fi
  echo "${result:-}"
}

motion.config.device()
{
  motion.log.trace "${FUNCNAME[0]}"

  local file=$(motion.config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.device' ${file})
  else
    motion.log.debug "no configuration file"
  fi
  echo "${result:-}"
}

motion.config.mqtt()
{
  motion.log.trace "${FUNCNAME[0]}"

  local file=$(motion.config.file)
  local result="null"

  if [ -s "${file}" ]; then
    result=$(jq -c '.mqtt?' ${file})
  else
    motion.log.warn "no configuration file"
  fi
  echo "${result:-}"
}

motion.config.cameras()
{
  motion.log.trace "${FUNCNAME[0]}"

  local file=$(motion.config.file)
  local result="null"

  if [ -s "${file}" ]; then
    result=$(jq -c '.cameras?' ${file})
  fi
  echo "${result:-}"
}

motion.config.post_pictures()
{
  motion.log.trace "${FUNCNAME[0]}"

  local file=$(motion.config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.motion.post_pictures' ${file})
  fi
  echo "${result:-}"
}

motion.config.file()
{
  motion.log.trace "${FUNCNAME[0]}"

  local conf="${MOTION_CONF:-}"
  if [ ! -z "${conf:-}" ]; then
    conf="${MOTION_CONF%/*}/motion.json"
  else
    conf="/etc/motion/motion.json"
    motion.log.warn "using default, static, motion configuration JSON file: ${conf}"
  fi
  echo "${conf:-}"
}

##
## MQTT
##

_motion.mqtt.pub()
{
  local ARGS=${*}

  if [ ! -z "$(motion.config.file)" ] && [ -s $(motion.config.file) ]; then
    local username=$(echo $(motion.config.mqtt) | jq -r '.username')
    local port=$(echo $(motion.config.mqtt) | jq -r '.port')
    local host=$(echo $(motion.config.mqtt) | jq -r '.host')
    local password=$(echo $(motion.config.mqtt) | jq -r '.password')

    if [ ! -z "${ARGS}" ]; then
      if [ ! -z "${username}" ] && [ "${username}" != 'null' ]; then
	ARGS='-u '"${username}"' '"${ARGS}"
      fi
      if [ ! -z "${password}" ] && [ "${password}" != 'null' ]; then
	ARGS='-P '"${password}"' '"${ARGS}"
      fi
      mosquitto_pub -i "$(motion.config.device)" -h "${host}" -p "${port}" ${ARGS}
    fi
  fi
}

motion.mqtt.pub()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"
  _motion.mqtt.pub "${*}"
}
 
mqtt_pub()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"
  _motion.mqtt.pub "${*}"
}

##
## logging
##

MOTION_LOG_LEVEL_EMERG=0
MOTION_LOG_LEVEL_ALERT=1
MOTION_LOG_LEVEL_CRIT=2
MOTION_LOG_LEVEL_ERROR=3
MOTION_LOG_LEVEL_WARN=4
MOTION_LOG_LEVEL_NOTICE=5
MOTION_LOG_LEVEL_INFO=6
MOTION_LOG_LEVEL_DEBUG=7
MOTION_LOG_LEVEL_TRACE=8
MOTION_LOG_LEVEL_ALL=9
MOTION_LOG_LEVELS=(EMERGENCY ALERT CRITICAL ERROR WARNING NOTICE INFO DEBUG TRACE ALL)
MOTION_LOG_FORMAT_DEFAULT='[TIMESTAMP] LEVEL >>>'
MOTION_TIMESTAMP_DEFAULT='%FT%TZ'
MOTION_LOG_FORMAT="${MOTION_LOG_FORMAT:-${MOTION_LOG_FORMAT_DEFAULT}}"
MOTION_LOG_LEVEL="${MOTION_LOG_LEVEL:-${MOTION_LOG_LEVELS[${MOTION_LOG_LEVEL_INFO}]}}"
MOTION_TIMESTAMP_FORMAT="${MOTION_TIMESTAMP_FORMAT:-${MOTION_TIMESTAMP_DEFAULT}}"

# logging by level

motion.log.emerg()
{ 
  motion.log.logto ${MOTION_LOG_LEVEL_EMERG} "${*}"
}

motion.log.alert()
{
  motion.log.logto ${MOTION_LOG_LEVEL_ALERT} "${*}"
}

motion.log.crit()
{
  motion.log.logto ${MOTION_LOG_LEVEL_CRIT} "${*}"
}

motion.log.error()
{
  motion.log.logto ${MOTION_LOG_LEVEL_ERROR} "${*}"
}

motion.log.warn()
{
  motion.log.logto ${MOTION_LOG_LEVEL_WARN} "${*}"
}

motion.log.notice()
{
  motion.log.logto ${MOTION_LOG_LEVEL_NOTICE} "${*}"
}

motion.log.info()
{
  motion.log.logto ${MOTION_LOG_LEVEL_INFO} "${*}"
}

motion.log.debug()
{
  motion.log.logto ${MOTION_LOG_LEVEL_DEBUG} "${*}"
}

motion.log.trace()
{
  motion.log.logto ${MOTION_LOG_LEVEL_TRACE} "${*}"
}

motion.log.level()
{
  case "${MOTION_LOG_LEVEL}" in
    emerg) LL=${MOTION_LOG_LEVEL_EMERG} ;;
    alert) LL=${MOTION_LOG_LEVEL_ALERT} ;;
    crit) LL=${MOTION_LOG_LEVEL_CRIT} ;;
    error) LL=${MOTION_LOG_LEVEL_ERROR} ;;
    warn) LL=${MOTION_LOG_LEVEL_WARN} ;;
    notice) LL=${MOTION_LOG_LEVEL_NOTICE} ;;
    info) LL=${MOTION_LOG_LEVEL_INFO} ;;
    debug) LL=${MOTION_LOG_LEVEL_DEBUG} ;;
    trace) LL=${MOTION_LOG_LEVEL_TRACE} ;;
    *) LL=${MOTION_LOG_LEVEL_ALL} ;;
  esac
  echo ${LL:-${MOTION_LOG_LEVEL_ALL}}
}

motion.log.mqtt()
{
  if [ "${MOTION_LOG_MQTT:-false}" = 'true' ]; then
    local level=${1:-0}
    local group=$(motion.config.group)
    local device=$(motion.config.device)

    motion.mqtt.pub -t "${group}/${device}/log/${MOTION_LOG_LEVELS[${level}]}" -m "${*}"
  fi
}

motion.log.message()
{
  local level="${1:-}"
  local message="${2:-}"
  local timestamp=$(date -u +"${MOTION_TIMESTAMP_FORMAT}")
  local output="${MOTION_LOG_FORMAT}"

  output=$(echo "${output}" | sed 's/TIMESTAMP/'${timestamp}'/')
  output=$(echo "${output}" | sed 's/LEVEL/'${MOTION_LOG_LEVELS[${level}]}'/')
  echo "${0##*/} $$ ${output} ${message}"
}

motion.log.logto()
{
  local level="${1:-0}"
  local current=$(motion.log.level)
  local exp='^[0-9]+$'

  if ! [[ ${level} =~ ${exp} ]] ; then
   echo "motion.log.logto: error: level ${level} not a number ${FUNCNAME}" &> ${LOGTO}
   level=
  fi
  if ! [[ ${current} =~ ${exp} ]] ; then
   echo "motion.log.logto: error: current ${current} not a number ${FUNCNAME}" &> ${LOGTO}
   current=
  fi
  if [ "${level:-0}" -le ${current:-9} ]; then
    local output=$(motion.log.message ${level} "${2:-}") 
    echo "${output}" &>> ${MOTION_LOGTO:-/tmp/motion.log}
    motion.log.mqtt ${level} "${output}"
  fi
}
