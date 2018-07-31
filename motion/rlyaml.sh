#!/bin/tcsh

echo "$0:t $$ -- START $*" >& /dev/stderr

if ($?HASSIO_TOKEN == 0) then
  if ("${1}" == "") then
    echo "$0:t $$ -- [ERROR] No HASSIO_TOKEN; please specify home-assistant password on command line; exiting"
    exit
  endif
  set HASSIO_PASSWORD = "${1}"
endif

if ($?CONFIG_PATH == 0) then
  set CONFIG_PATH = "$cwd"
  set CONFIG = $cwd/config
else
  set CONFIG = /config
endif

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

  set current = "${CONFIG}/${rl}.yaml"
  set additional = "$CONFIG_PATH:h/${rl}.yaml"
  set original = "$CONFIG_PATH:h/${rl}.yaml.orig"

  echo "$0:t $$ -- [INFO] current $current additional $additional original $original" >& /dev/stderr

  if ((! -e "$current") && (! -e "$original")) then
    echo "$0:t $$ -- [INFO] No existing $current; copying $additional" >& /dev/stderr
    cp "$additional" "$current"
    continue
  endif

  if (-s "$additional" && (-M "$additional") > (-M "$current")) then
    if (! -e "$original") cp "$current" "$original"
    cat "$original" "$additional" >! "$current"
    if ( $i <= $#reload && $?HASSIO_TOKEN) then
      echo -n "$0:t $$ -- [INFO] Reloading YAML configuration for: ${rl} ... "
      curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/${rl}/reload"
      echo "done"
    else
      set reload_core
    endif
  else
    echo -n "$0:t $$ -- [INFO] Nothing to update for ${rl}"
  endif
end

if ($?reload_core && $?HASSIO_TOKEN) then
  echo -n "$0:t $$ -- [INFO] Reloading core YAML configuration ... "
  curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/homeassistant/reload_core_config"
  echo "done"
endif

echo "$0:t $$ -- FINISH" >& /dev/stderr
