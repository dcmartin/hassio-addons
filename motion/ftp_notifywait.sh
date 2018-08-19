#!/bin/tcsh

if ($?MOTION_JSON_FILE == 0) then
  echo "No MOTION_JSON_FILE"
  exit
endif

echo "$0:t $$ -- START"

set CAMERAS = ( `jq '.cameras' "${MOTION_JSON_FILE}"` )
set names = ( `echo "$CAMERAS" | jq -r '.[]|.name'` )

echo "$0:t $$ -- CAMERAS: $CAMERAS"

foreach name ( $names )
  set url = `echo "$CAMERAS" | jq -r '.[]|select(.name=="'"$name"'").url'`
  echo "$0:t $$ -- camera $name at URL $url"
  if ($#url && $url =~ 'ftpd://*') then
    set input = `echo "$url" | sed "s/.*:\/\///"`
    set output = $input
    set input = $input:r
    mkdir -p "$input"
    echo "$0:t $$ -- waiting on $input to create $output" >& /dev/stderr
    cp -f /etc/motion/sample.jpg "$output"
    do_ftp_notifywait.sh "$input" "$output" &
  endif
end

echo "$0:t $$ -- FINISH"
