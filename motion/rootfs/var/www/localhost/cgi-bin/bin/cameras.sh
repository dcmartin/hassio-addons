#!/bin/bash

###
### THIS SCRIPT LISTS EVENTS FOR THE DEVICE
###
### CONSUMES THE FOLLOWING ENVIRONMENT VARIABLES:
###
### + MOTION_APACHE_HTDOCS
###

DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras

if [ -d "${DIR:-}" ]; then
  echo '{"timestamp":"'$(date -u +%FZ%TZ)'","cameras":['; \
    i=0; ls -1 ${DIR} \
      | while read; do r="${REPLY##*/}"; r=${r%%.*}; \
          if [ ${i} -gt 0 ]; then echo ','; fi; \
          echo '{"id":"'${r}'","events":'; \
          ls -1 ${DIR}/${REPLY} | wc -l; \
          echo '}'; \
	  i=$((i+1)); done
  echo ']}'
else
  echo 'null'
fi

