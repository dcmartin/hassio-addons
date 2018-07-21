#!/bin/csh -fb

setenv DEBUG true
# setenv VERBOSE true

if ($#argv < 1) then
  echo "USAGE: $0:t <video> .."
endif

echo "<html><body>"

foreach video ( $argv )

if (! -e "$video") then
  echo "ERROR: $0:t cannot find $video"
  exit
endif

##
## VARIABLE PROCESSING
##

# fuzzy matching for comparison metric
@ fuzz = 20

# 
set blur = "0x3"

# threshold comparison
@ blur = 10
@ low = 20
@ high = 50

# frames per second
@ fps = 10

# delay (milliseconds)
set ms = `echo "$fps / 60.0 * 100.0" | bc -l`
@ ms = $ms:r

# make JSON details
set json = "$video:t:r.json"
if (! -e "$json") then
  # identify -verbose -features 1 -moments -unique "$video" | convert rose: json:- | jq '.' >! "$json"
  identify -verbose -moments -unique "$video" | convert rose: json:- | jq '.' >! "$json"
else
  if ($?DEBUG) echo "$0:t $$ -- video ($video)" `jq -c '.' "$json"` >&! /dev/stderr
endif

##
## BREAKDOWN INTO FRAMES
##

set template = "$video:t:r.%04d.png"
ffmpeg -r "$fps" -i $video "$template" >&! /dev/null

set frames = ( `echo $video:t:r.*.png` )
if ($#frames < 1) then
  echo "ERROR: $0:t -- no frames ($video)"
  exit
else
  if ($?DEBUG) echo "$0:t $$ -- $#frames frames from video ($video) @ $fps FPS" >& /dev/stderr
endif

##
## MAKE AVERAGE FRAME
##
set average = $video:t:r.png
convert $frames -average $average

##
## CALCULATE FRAME CHANGES
##

@ t = 0
@ i = 1
set ps = ()
set diffs = ()
while ( $i < $#frames )
    set diffs = ( $diffs $frames[$i]:r.jpg )
    # calculate difference
    @ j = $i + 1
    set p = ( `compare -metric fuzz -fuzz "$fuzz"'%' $frames[$i] $frames[$j] -compose src -highlight-color white -lowlight-color black $diffs[$#diffs] |& awk '{ print $1 }'` )
    if ($?VERBOSE) echo "$0:t $$ -- $diffs[$#diffs] change = $p" >& /dev/stderr
    # keep track of differences
    set ps = ( $ps $p:r )
    @ t += $ps[$#ps]
    @ i++
end

##
## CALCULATE AVERAGE CHANGE
##
@ a = ( `echo "$t / $#ps" | bc` )

if ($?DEBUG) echo "$0:t $$ -- average change ($a) @ fuzz $fuzz %" >& /dev/stderr

##
## COLLECT KEY FRAMES
##

@ i = 1
set kpng = ()
set kjpg = ()
while ( $i <= $#ps )
    # keep track of frames w/ change > average
    if ($ps[$i] > $a) then
      if ($?VERBOSE) echo "$0:t $$ -- $frames[$i] ($i)" >& /dev/stderr
      set kpng = ( $kpng $frames[$i] )
      set kjpg = ( $kjpg $frames[$i]:r.jpg )
    endif
    @ i++
end

##
## COMPOSITE KEY FRAMES AGAINST AVERAGE USING MASK
##

set composite = "$average:r.jpeg"
cp "$average" "$composite"

@ i = 1
while ( $i <= $#kpng )
  convert $kpng[$i] $composite $kjpg[$i] -composite $composite:r.$i.jpeg
  open $composite:r.$i.jpeg
  cp $composite:r.$i.jpeg $composite
  @ i++
end

##
## make sample
##

convert -delay $ms $kpng $video:t:r.gif
convert -delay $ms $kjpg $video:t:r.mask.gif

# rm -f $frames $diffs

echo '<img src="'$video:t:r.gif'"><img src="'$video:t:r.mask.gif'"><br>' 

end

echo "</body></html>"
