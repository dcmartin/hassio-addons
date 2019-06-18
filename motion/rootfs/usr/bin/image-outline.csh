#!/bin/csh -fb

setenv DEBUG true

if ($?DEBUG) /bin/echo "$0 $$ -- START $*" `date` >&! /dev/stderr

###
### ARGS
###

if ($#argv == 9) then
  set file = $1
  set target = ( $2 $3 $4 $5 )
  set sensor = ( $6 $7 $8 $9 )
  if (! -e "$file") then
    /bin/echo "$0 $$ -- NO FILE ($file)" >&! /dev/stderr
    goto done
  endif
else
  /bin/echo "$0 $$ -- BAD ARGS [$#argv] ($argv)" >&! /dev/stderr
endif

###
### OUTPUT
###

set out = "$file:r.$$.$file:e"

###
### DRAW BOUNDING BOX(s)
###

convert "$file" \
  -fill none \
  -stroke red \
  -strokewidth 3 \
  -draw "rectangle $target" \
  -composite \
  -fill none \
  -stroke white \
  -strokewidth 3 \
  -draw "rectangle $sensor" \
  "$out" >&! /dev/stderr

###
### OUTPUT
###

if (-e "$out") then
  /bin/echo "$0 ($$) -- OUTPUT SUCCESSFUL $out ($target)" >&! /dev/stderr
  /bin/dd if="$out"
  /bin/rm -f "$out"
endif

###
### DONE
###

done:
  if ($?DEBUG) /bin/echo "$0 ($$) -- FINISHED" `date` >&! /dev/stderr
