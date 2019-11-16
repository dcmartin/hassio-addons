#!/usr/bin/with-contenv bashio

###
### run.sh
###

bashio::log.notice $(date) "$0 $*"

## have to have configuration file
if [ ! -s "${CONFIG_PATH}" ]; then
  bashio::log.error "cannot find options ${CONFIG_PATH}; exiting"
  exit
fi

###
### start
###

/usr/bin/motion.sh "$(bashio::string.lower "$(bashio::config log_level)")"
