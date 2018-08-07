#!/bin/tcsh

echo "$0:t $$ -- START $*" >& /dev/stderr

if ($?HASSIO_TOKEN == 0) then
  if ("${1}" == "") then
    echo "$0:t $$ -- [ERROR] No HASSIO_TOKEN; please specify home-assistant password on command line; exiting"
    exit
  endif
  set HASSIO_PASSWORD = "${1}"
endif

set CONFIG = /config
set DATA_DIR = /data
set TMPFS = /tmpfs

# core modules require core reload
# set all = ( `echo "$CONFIG/"*.yaml | sed "s|.*/\([^\.]*\).yaml|\1|"` )
set all = ( group automation script configuration input_boolean input_text input_select ui-lovelace )

# find which modules can be reloaded
if ($?HASSIO_TOKEN) then
  set HASSIO_HOST = "hassio/homeassistant"
  set reload = ( `curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" "http://${HASSIO_HOST}/api/services" | jq -r '.[]|select(.services.reload.description != null)|.domain'` )
else if ($#argv) then
  set HASSIO_HOST = "localhost:8123"
  set reload = ( `curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_PASSWORD}" "http://${HASSIO_HOST}/api/services" | jq -r '.[]|select(.services.reload.description != null)|.domain'` )
endif

if ($#reload == 0) then
  echo "$0:t $$ -- [ERROR] Cannot determine modules for reload" >& /dev/stderr
  set reload = ()
  set core = ( $all )
else
  set core = ()
  foreach yf ( $all )
    unset found
    @ i = 1
    while ($i <= $#reload)
      if ($yf == $reload[$i]) then
        set found
	break
      endif
      @ i++
    end
    if ($?found) continue
    set core = ( $core $yf )
  end
endif

echo "$0:t $$ -- [INFO] Found $#core core components and $#reload reloadable component(s)" >& /dev/stderr

@ i = 0
foreach rl ( $reload $core )
  @ i++

  set current = "$CONFIG/${rl}.yaml"
  set currents = "$CONFIG/${rl}s.yaml"
  set additional = "$DATA_DIR/${rl}.yaml"
  set base = "$DATA_DIR/${rl}.yaml.base"
  set original = "$DATA_DIR/${rl}.yaml.orig"

  if (-e "$currents") set current = "$currents"

  echo "$0:t $$ -- [INFO] current $current additional $additional original $original" >& /dev/stderr

  if (`egrep '### MOTION' "$current" | wc -c | awk '{ print $1 }'` > 0) then
    rm -f "$current"
  endif

  if (-s "$additional") then
    if ((! -e "$current" || (`jq -r '.==[]' "$current"` == "true")) && (! -s "$original")) then
      if (-s "$base") then
        echo "$0:t $$ -- [INFO] creating YAML ($current) from $base and $additional" >& /dev/stderr
        cat "$base" "$additional" >! "$current"
      else
        echo "$0:t $$ -- [INFO] creating YAML ($current) from $additional alone" >& /dev/stderr
        cat "$additional" >! "$current"
      endif
      continue
    endif
    if (! -e "$original") cp "$current" "$original"
    cat "$original" "$additional" >! "$current"
    if ( $i <= $#reload && $?HASSIO_TOKEN) then
      echo -n "$0:t $$ -- [INFO] updating YAML: ${rl} ... "
      curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/${rl}/reload" >& /dev/null
      echo "done"
    else
      set reload_core
    endif
  else
    echo "$0:t $$ -- [INFO] no additional YAML: ${rl}"
  endif
end

if ($?reload_core && $?HASSIO_TOKEN) then
  echo -n "$0:t $$ -- [INFO] Reloading core YAML configuration ... "
  curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/homeassistant/reload_core_config" >& /dev/null
  echo "done"
endif

echo "$0:t $$ -- FINISH" >& /dev/stderr
