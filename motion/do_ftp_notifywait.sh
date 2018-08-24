#!/bin/bash

DIR="${1}"
VAL="${2}"

# exec 0>&- # close stdin
# exec 1>&- # close stdout
# exec 2>&- # close stderr

touch "${VAL}"

inotifywait -m -r -e close_write --format '%w%f' "${DIR}" | while read FULLPATH
do
  on_ftp_notifywait.sh "${FULLPATH}" "${VAL}"
done
