#!/bin/tcsh

setenv DEBUG
setenv VERBOSE

if ($?VERBOSE) echo "$0:t $$ -- START $*" `date` >>& /tmp/motion.log

if ($#argv == 2) then
  set file = "$argv[1]"
  set output = "$argv[2]"
  if (-s "$file") then
    switch ("$file:e")
      case "3gp":
	on_new_3gp.sh "$file" "$output"
	breaksw
      case "jpg":
	on_new_jpg.sh "$file" "$output"
	breaksw
      default:
	if ($?DEBUG) echo "$0:t $$ -- $file:e unimplemented" >>& /tmp/motion.log
	breaksw
    endsw
  else
    echo "$0:t $$ -- no such file: $file" >>& /tmp/motion.log
  endif
else
  echo "$0:t $$ -- invalid arguments $*" >>& /tmp/motion.log
endif

done:
  if ($?VERBOSE) echo "$0:t $$ -- FINISH" `date` >>& /tmp/motion.log
