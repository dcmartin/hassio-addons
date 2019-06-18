#!/bin/csh -fb

setenv DEBUG true

if ($?DEBUG) /bin/echo "$0 $$ -- START $*" `date` >&! /dev/stderr

###
### ARGS
###

set file = $1
set size = $2
set xform = $3
set rect = "$argv[4-]"

## output
set out = "$file:r.$$.$file:e"

### CROP IMAGE

## two steps
set temp = `mktemp`
set temp = "$temp.$out:e"
## step 1
convert -crop "$xform" "$file" -gravity center -background gray "$temp"

## step 2 iff step 1
if (-e "$temp") then
  # make some noise
  set noise = `mktemp`
  set noise = "$noise.$out:e"
  convert -size "$size" 'xc:' '+noise' Random "$noise"
  if (-e "$noise") then
    set comp = `mktemp`
    set comp = "$comp.$out:e"
    composite -compose src -geometry +"$rect[1]"+"$rect[2]" "$out.$$" "$noise" "$comp"
    if (-e "$comp") then
      mv "$comp" "$out"
    endif
    /bin/rm -f "$comp" "$noise" "$temp"
  else
    if ($?DEBUG) /bin/echo "$0 $$ -- FAILED TO MAKE NOISE $noise" >&! /dev/stderr
  endif
else
  if ($?DEBUG) /bin/echo "$0 $$ -- FAILURE TO CROP ($cropped)" >&! /dev/stderr
endif

## output iff output
if (-e "$out") then
  /bin/echo "$0 ($$) -- OUTPUT SUCCESSFUL $out ($rect)" >&! /dev/stderr
  /bin/dd if="$out"
  /bin/rm -f "$out"
endif

###
### DONE
###

done:
  if ($?DEBUG) /bin/echo "$0 ($$) -- FINISHED" `date` >&! /dev/stderr
