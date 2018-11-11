#!/bin/tcsh

echo "$0:t $$ -- START"

if ($#argv == 0) then
  echo "$0:t $$ -- MOTION_JSON_FILE is not set"
  exit
else if ( ! -s "${1}") then
  echo "$0:t $$ -- MOTION_JSON_FILE ${1} is not found"
  exit
else
  set MOTION_JSON_FILE="${1}"
  echo "$0:t $$ -- Found MOTION_JSON_FILE ${1}"
endif

set CAMERAS = ( `jq '.cameras' "${MOTION_JSON_FILE}"` )
if ($#CAMERAS && "$CAMERAS" != "null") then
  set names = ( `echo "$CAMERAS" | jq -r '.[]|.name'` )
else
  echo "$0:t $$ -- ERROR !! no cameras in ${MOTION_JSON_FILE}"
  got done
endif

echo "$0:t $$ -- CAMERAS: $CAMERAS"

foreach name ( $names )
  set noglob
  set url = ( `echo "$CAMERAS" | jq -r '.[]|select(.name=="'"$name"'").url'` )
  echo "$0:t $$ -- camera $name at URL $url"
  if ($#url && $url =~ 'ftpd://*') then
    set input = `echo "$url" | sed "s|ftpd://||"`
    set output = $input
    set input = $input:r
    mkdir -p "$input"
    echo "$0:t $$ -- waiting on $input to create $output" >& /dev/stderr
    cp -f /etc/motion/sample.jpg "$output"
    do_ftp_notifywait.sh "$input" "$output" &
  endif
  unset noglob
end

done:

echo "$0:t $$ -- FINISH"
