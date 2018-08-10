#!/bin/tcsh

echo "$0:t $$ -- START $*" >& /dev/stderr

if ($?HASSIO_TOKEN == 0) then
  if ("${1}" == "") then
    echo "$0:t $$ -- [ERROR] No HASSIO_TOKEN; please specify home-assistant password on command line; exiting"
    exit
  endif
  set HASSIO_PASSWORD = "${1}"
endif

## test iff reconfiguration
if ($#argv > 1) set RECONFIG = "${2}"

set CONFIG = /config
set DATA_DIR = /data
set TMPFS = /tmpfs

# core modules require core reload
## GET COMPONENTS
set components = ( `echo $DATA_DIR/*.yaml | sed 's|'"$DATA_DIR"'/\(.*\).yaml|\1|'` )

set all = ( $components "ui-lovelace" )

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

echo "$0:t $$ -- [INFO] For $#all found $#core core components and $#reload reloadable component(s)" >& /dev/stderr

@ i = 0
foreach rl ( $reload $core )
  @ i++

  set current = "$CONFIG/${rl}.yaml"
  set reconfig = "$DATA_DIR/${rl}.yaml"

  echo "$0:t $$ -- [INFO] current $current new $reconfig" >& /dev/stderr

  set currents = "$CONFIG/${rl}s.yaml"; if (-e "$currents") rm "$currents"

  if (-s "$reconfig") then
    echo "$0:t $$ -- [INFO] creating YAML ($current) from $reconfig alone" >& /dev/stderr
    cat "$reconfig" >! "$current"
  else if (-s "$current") then
    echo "$0:t $$ -- [INFO] no reconfig YAML: ${rl}; removing $current" >& /dev/stderr
    rm -f "$current"
  else
    echo "$0:t $$ -- [INFO] no YAML: ${rl}" >& /dev/stderr
  endif
end

if ($?HASSIO_TOKEN) then
  echo -n "$0:t $$ -- [INFO] Reloading YAML configuration ... " >& /dev/stderr
  curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/homeassistant/reload_core_config" >& /dev/null
  echo "done" >& /dev/stderr
else
    echo "$0:t $$ -- [ERROR] Failed to issue reload; no HASSIO_TOKEN" >& /dev/stderr
endif

echo "$0:t $$ -- FINISH" >& /dev/stderr
