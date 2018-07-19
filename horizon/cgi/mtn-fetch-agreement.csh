#!/bin/csh -fb

if ($#argv == 2) then
  set ip = "$argv[1]"
  set json = "$argv[2]"
else
  /bin/echo "$0:t <ip> <json>"
  exit
endif

set time = 30

/usr/bin/curl -s -q -f -k -m $time -L0 "http://192.168.1.$ip/agreement" -o "$json.$$"
set code = "$status"
if ($code != 22 && $code != 28 && -s "$json.$$") then
  /usr/local/bin/jq '.' "$json.$$" >! "$json"
  /bin/rm -f "$json.$$"
else
  exit "$code"
endif
