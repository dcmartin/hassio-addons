#!/bin/tcsh

echo "$0:t $$ -- START $*" >& /dev/stderr

## TEST ENVIRONMENT
if ($?CONFIG_PATH == 0) then
  echo "$0:t $$ -- [ERROR] no CONFIG_PATH environment; exiting" >& /dev/stderr
  goto done
endif
setenv CONFIG_DIR /config

if ($?HASSIO_TOKEN == 0) then
  if ($#argv > 1) then
    set HASSIO_PASSWORD = "$argv[2]"
  else
    echo "$0:t $$ -- [WARN] No HASSIO_TOKEN; no HASSIO_PASSWORD specified on command line" >& /dev/stderr
  endif
endif

## HANDLE ARGS
if ($#argv) then
  set RELOAD = ( $argv )
endif
if ($?RELOAD == 0) then
  echo "$0:t $$ -- [ERROR] insufficient arguments; please specify reload (true, false, lovelace); exiting" >& /dev/stderr
  goto done
endif

## GET COMPONENTS
set DATA_DIR = $CONFIG_PATH:h
set all = ( `echo $DATA_DIR/*.yaml | sed 's|'"$DATA_DIR"'/\([^\.]*\).yaml|\1|g'` )
if ($#all == 0) then
  echo "$0:t $$ -- [ERROR] no YAML files found in $DATA_DIR; exiting" >& /dev/stderr
  goto done
endif

## RELOAD WHAT?
set reload = ()
if ($#RELOAD == 1) then
  if ($RELOAD == "false") then
    echo "$0:t $$ -- [INFO] reload is $RELOAD; exiting" >& /dev/stderr
    goto done
  else if ($RELOAD == "true" || $RELOAD == "all") then
    set RELOAD = ( $all )
  else
    echo "$0:t $$ -- [INFO] reload is $RELOAD; continuing" >& /dev/stderr
  endif
endif
foreach rl ( $RELOAD )
  unset found
  foreach c ( $all )
    if ("$rl" == "$c") then
      set found
      break
    endif
  end
  if ($?found) then
    set yf = "$DATA_DIR/${rl}.yaml"
    if (-e "$yf") then
      set reload = ( "$rl" $reload )
    else
      echo "$0:t $$ -- [ERROR] did not find YAML: $yf" >& /dev/stderr
    endif
  else 
    echo "$0:t $$ -- [WARN] no YAML for reload component: $rl" >& /dev/stderr
  endif
end

echo "$0:t $$ -- [INFO] $#all YAML; requested $#RELOAD; reloading $#reload components" >& /dev/stderr

## PROCESS RELOAD
@ i = 0
foreach rl ( $reload )
  @ i++

  set current = "$CONFIG_DIR/${rl}.yaml"
  set reconfig = "$DATA_DIR/${rl}.yaml"

  # remove legacy/extraneous yaml
  set currents = "$CONFIG_DIR/${rl}s.yaml"; if (-e "$currents") rm "$currents"

  echo "$0:t $$ -- [INFO] over-writing $current with $reconfig" >& /dev/stderr
  cat "$reconfig" >! "$current"
end

if ($#reload) then
  # find which modules can be reloaded
  if ($?HASSIO_TOKEN) then
    set HASSIO_HOST = "hassio/homeassistant"
    set reloadable = ( `curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" "http://${HASSIO_HOST}/api/services" | jq -r '.[]|select(.services.reload.description != null)|.domain'` )
  else if ($?HASSIO_PASSWORD) then
    set HASSIO_HOST = "localhost:8123"
    set reloadable = ( `curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_PASSWORD}" "http://${HASSIO_HOST}/api/services" | jq -r '.[]|select(.services.reload.description != null)|.domain'` )
  else
    echo "$0:t $$ -- [WARN] no access to HASSIO_HOST; missing environment; no reloadable components" >& /dev/stderr
  endif

  if ($?HASSIO_TOKEN) then
    echo -n "$0:t $$ -- [INFO] Reloading core configuration for $HASSIO_HOST ... " >& /dev/stderr
    curl -s -q -f -L -H "X-HA-ACCESS: ${HASSIO_TOKEN}" -X POST -H "Content-Type: application/json" "http://${HASSIO_HOST}/api/services/homeassistant/reload_core_config" >& /dev/null
    echo "done" >& /dev/stderr
  else
    echo "$0:t $$ -- [WARN] Did not issue reload; no HASSIO_TOKEN" >& /dev/stderr
  endif
else
  echo "$0:t $$ -- [INFO] Nothing to reload" >& /dev/stderr
endif

done:

echo "$0:t $$ -- FINISH" >& /dev/stderr
