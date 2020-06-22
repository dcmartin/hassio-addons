#!/bin/bash

###
### THIS SCRIPT LISTS EVENTS FOR THE DEVICE
###
### CONSUMES THE FOLLOWING ENVIRONMENT VARIABLES:
###
### + MOTION_APACHE_HTDOCS
###

DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras/${1-}

if [ -d "${DIR:-}" ]; then
  echo '{"timestamp":"'$(date -u +%FZ%TZ)'","events":['; \
    i=0; find ${DIR} -name "${2:-*}.json" -print \
      | while read; do r="${REPLY##*/}"; r=${r%%.*}; \
          if [ ${i} -gt 0 ]; then echo ','; fi; \
          echo '{"id":"'${r}'","event":'; \
          jq -c '.|.image=(.image!=null)' ${REPLY}; \
          echo '}'; \
	  i=$((i+1)); done
  echo ']}'
else
  echo 'null'
fi

