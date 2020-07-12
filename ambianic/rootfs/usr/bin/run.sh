#!/usr/bin/with-contenv bashio

###
### run.sh
###

bashio::log.notice $(date) "$0 $*"

###
### start
###

${USRBIN:-/usr/bin}/ambianic.sh "$(bashio::string.lower "$(bashio::config log_level)")"
