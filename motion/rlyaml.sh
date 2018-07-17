#!/bin/tcsh
if ($?HASSIO_TOKEN == 0) then
  if ("${1}" == "") then
    echo "[ERROR] No HASSIO_TOKEN; please specify home-assistant password on command line; exiting"
    exit
  endif
  set HASSIO_PW = '-H "x-ha-access: '"${1}"'"'
  set HASSIO_HOST = "p40.local:8123"
else
  set HASSIO_PW = '-u ":${HASSIO_TOKEN}"'
  set HASSIO_HOST = "hassio/homeassistant"
endif

if ($?CONFIG_PATH == 0) then
  set CONFIG_PATH = "$cwd"
  set CONFIG = $cwd/config
else
  set CONFIG = /config
endif

# find which modules can be reloaded
set reload = ( `curl -s -q -f -L "${HASSIO_PW}" "http://${HASSIO_HOST}/api/services" | jq -r '.[]|select(.services.reload.description != null)|.domain'` )

if ($#reload == 0) then
  echo "[ERROR] Cannot determine modules for reload" >& /dev/stderr
  set reload = ()
endif

foreach rl ( $reload configuration )
  set current = "${CONFIG}/${rl}.yaml"
  set additional = "${CONFIG_PATH}/${rl}.yaml"
  set original = "${CONFIG_PATH}/${rl}.yaml.orig"

  if ((! -e "$current") && (! -e "$original")) then
    echo "[INFO] No existing $current; copying $additional" >& /dev/stderr
    cp "$additional" "$current"
    continue
  endif
  if (-s "$additional" && (-M "$additional") > (-M "$current")) then
    if (! -e "$original") cp "$current" "$original"
    cat "$original" "$additional" >! "$current"
    echo -n "[INFO] Reloading YAML configuration for: ${rl} ... "
    if ( "$rl" != "configuration") then
      curl -s -q -f -L "${HASSIO_PW}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/${rl}/reload"
    else
      curl -s -q -f -L "${HASSIO_PW}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/homeassistant/reload_core_config"
    endif
    echo "done"
  else
    echo -n "[INFO] Nothing to update for ${rl}"
  endif
end
