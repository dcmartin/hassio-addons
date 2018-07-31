#!/bin/tcsh

if ($?MOTION_JSON_FILE == 0) then
  echo "No MOTION_JSON_FILE"
  exit
endif

set CAMERAS = ( `jq '.cameras' "${MOTION_JSON_FILE}"` )
set names = ( `echo "$CAMERAS" | jq -r '.[]|.name'` )

foreach name ( $names )
  set url = `echo "$CAMERAS" | jq -r '.[]|select(.name=="'"$name"'").url'`
  if ($#url && $url =~ 'file://*') then
    set input = `echo "$url" | sed "s/.*:\/\///"`
    set output = $input:h.jpg
    echo "$0:t $$ -- waiting on $input to create $output" >& /dev/stderr
    cp -f /etc/motion/sample.jpg "$output"
    do_ftp_notifywait.sh "$input" "$output" &
  endif
end
