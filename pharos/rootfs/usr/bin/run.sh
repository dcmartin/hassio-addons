#!/usr/bin/with-contenv /usr/bin/bashio

###
### run.sh
###

bashio::log.notice $(date) "$0 $*"

###
### start
###

${USRBIN:-/usr/bin}/pharos.sh "$(bashio::string.lower "$(bashio::config log_level)")"
