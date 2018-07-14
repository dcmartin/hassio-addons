#!/bin/csh

# setenv DEBUG true

## BOOTSTRAP FILE
if ($#argv >= 1) then
  set bootstrap = $argv[1]
endif
if ($?bootstrap == 0) then
  set bootstrap = "bootstrap.json"
endif
if (! -e "$bootstrap") then
  echo "$0:t $$ -- [ERROR] cannot find $bootstrap" > /dev/stderr
  exit 1
endif

## MAKE A COPY
jq '.' "$bootstrap" >! "$bootstrap.$$"
set bootstrap = "$bootstrap".$$

## SERVICES REQUESTED
set service_configs = ( `jq '.m_ServiceConfigs' $bootstrap` )
if ($#service_configs && "$service_configs" != "null") then
  set services = ( `jq -r '.m_ServiceConfigs[].m_ServiceId' "$bootstrap"` )
  if ($#services == 0 || "$services" == "null") then
    echo "$0:t $$ -- [ERROR] no services in $bootstrap" > /dev/stderr
    exit 1
  endif
else
  echo "$0:t $$ -- [INFO] no services to service_configsure" > /dev/stderr
  exit
endif

## APIKEYS DEFINED
set missing = ()
set complete = ()

## PROCESS ALL SERVICES
foreach s ( $services )
  # get configuration
  if ($?svc) then
    unset svc
  endif
  if ($?DEBUG) echo "$0:t $$ -- [DEBUG] ($s) configuration: $#service_configs" > /dev/stderr
  set noglob
  set svc = ( `echo "$service_configs" | jq '.[]|select(.m_ServiceId=="'$s'")'` )
  unset noglob
  if ($?svc == 0) then
    echo "$0:t $$ -- [ERROR] service ($s) cannot find configuration" > /dev/stderr
    exit 1
  endif
  if ($#svc == 0 || "$svc" == "null") then
    echo "$0:t $$ -- [WARN] service ($s) cannot find configuration ($#service_configs)" > /dev/stderr
    set missing = ( $missing $s )
    exit
  endif
  set p = ( `echo "$svc" | jq -r '.m_Password'` )
  if ($#p == 0 || "$p" == "null") then
    echo "$0:t $$ -- [INFO] service ($s) no existing password configuration" > /dev/stderr
    unset p
  else
    echo "$0:t $$ -- [INFO] service ($s) existing password ($p)" > /dev/stderr
  endif
  # get credentials
  set credentials = ( `echo "$svc" | jq '.credentials'` )
  if ($#credentials == 0 || "$credentials" == "null") then
    if ($?p == 0) then
      echo "$0:t $$ -- [WARN] service ($s) cannot find credentials" > /dev/stderr
      set missing = ( $missing $s )
    endif
    continue
  endif
  # get details
  set cp = ( `echo "$credentials" | jq -r '.password'` )
  set cn = ( `echo "$credentials" | jq -r '.username'` )
  set cu = ( `echo "$credentials" | jq -r '.url'` )
  if ($#cp && "$cp" != "null") then
    if ($?DEBUG) echo "$0:t $$ -- [DEBUG] service ($s) has $#cp password ($cp) and $#cn username ($cn)" > /dev/stderr
  else if ($?p == 0) then
    echo "$0:t $$ -- [WARN] service ($s) has insufficient credentials; $#cp password" > /dev/stderr
    set missing = ( $missing $s )
    continue
  else
    unset cp
  endif
  if ($?p && $?cp) then
    if ("$cp" == "$p") then
      if ($?DEBUG) echo "$0:t $$ -- [DEBUG] service ($s) password configuration matches credentials ($p)" > /dev/stderr
      continue
    endif
  else if ($?p) then
    if ($?DEBUG) echo "$0:t $$ -- [DEBUG] service ($s) has existing password ($p)" > /dev/stderr
    continue
  endif
  # update configuration with credentials 
  set noglob
  set svc = ( `echo "$svc" | jq '.m_Password="'$cp'"'` )
  set svc = ( `echo "$svc" | jq '.m_User="'$cn'"'` )
  unset noglob
  if ($?DEBUG) echo "$0:t $$ -- [DEBUG] service ($s) configured: $svc" > /dev/stderr
  set noglob
  set service_configs = ( `echo "$service_configs" | jq '[.[]|select(.m_ServiceId=="'$s'")='"$svc"']'` )
  unset noglob
  if ($?DEBUG) echo "$0:t $$ -- [DEBUG] configuration count [$#service_configs]" > /dev/stderr
  set complete = ( $complete $s )
end

if ($#missing) then
  echo "$0:t $$ -- [WARN] $#missing missing services" > /dev/stderr
endif

if ($#complete) then
  echo "$0:t $$ -- [INFO] $#complete complete services" > /dev/stderr
  if ($?DEBUG) echo "$0:t $$ -- [DEBUG] service_configsuration ($#service_configs)" > /dev/stderr
  jq '.m_ServiceConfigs='"$service_configs" "$bootstrap" >! "$bootstrap:r"
  rm -f "$bootstrap"
endif
