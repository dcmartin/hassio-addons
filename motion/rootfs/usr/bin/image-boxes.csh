#!/bin/csh -fb

setenv DEBUG true

## START
if ($?DEBUG) /bin/echo "$0 $$ -- START $*" `date` >&! /dev/stderr

## DEFAULTS
if ($?CAMERA_IMAGE_WIDTH == 0) setenv CAMERA_IMAGE_WIDTH 640
if ($?CAMERA_IMAGE_HEIGHT == 0) setenv CAMERA_IMAGE_HEIGHT 480
if ($?MODEL_IMAGE_WIDTH == 0) setenv MODEL_IMAGE_WIDTH 224
if ($?MODEL_IMAGE_HEIGHT == 0) setenv MODEL_IMAGE_HEIGHT 224

## validate arguments
if ($#argv == 4) then
  @ cx = $1
  @ cy = $2
  @ width = $3
  @ height = $4
  if ($?cx && $?cy && $?width && $?height) then
    if ($#cx && $#cy && $#width && $#height) then
    else
      if ($?DEBUG) /bin/echo "$0 $$ -- BAD ARGS ($argv)" >&! /dev/stderr
      goto done
    endif
  else
    if ($?DEBUG) /bin/echo "$0 $$ -- UNSPECIFIED ARGS ($argv)" >&! /dev/stderr
    goto done
  endif
else
  if ($?DEBUG) /bin/echo "$0 $$ -- INSUFFICIENT ARGS ($argv)" >&! /dev/stderr
  goto done
endif

###
### CALCULATE BOXES
###

## X (LEFT)
@ x = `echo "$cx - ( $width / 2 )" | bc`
if ($?x == 0) @ x = 0
if ($#x == 0) @ x = 0
if ($x < 0 || $x > $CAMERA_IMAGE_WIDTH) @ x = 0

## Y (TOP)
@ y = `echo "$cy - ( $height / 2 )" | bc`
if ($?y == 0) @ y = 0
if ($#y == 0) @ y = 0
if ($y < 0 || $y > $CAMERA_IMAGE_HEIGHT) @ y = 0

## W (WIDTH)
set w = $width
if ($?w == 0) @ w = $CAMERA_IMAGE_WIDTH
if ($w <= 0 || $w > $CAMERA_IMAGE_WIDTH) @ w = $CAMERA_IMAGE_WIDTH

## H (HEIGHT)
set h = $height
if ($?h == 0) @ h = $CAMERA_IMAGE_HEIGHT
if ($h <= 0 || $h > $CAMERA_IMAGE_HEIGHT) @ h = $CAMERA_IMAGE_HEIGHT

###
### MOTION crop (motion)
###

## motion (TOP-LEFT to LOWER-RIGHT)
@ ew = $x + $w
@ eh = $y + $h
set motion = ( $x $y $ew $eh )

###
### MODEL crop (sensor) and transform (xform)
###

# subtract off half of model size
@ sx = $cx - ( $MODEL_IMAGE_WIDTH / 2 )
if ($sx < 0) @ sx = 0
@ sy = $cy - ( $MODEL_IMAGE_HEIGHT / 2 )
if ($sy < 0) @ sy = 0
# adjust for scale
@ sw = $MODEL_IMAGE_WIDTH
@ sh = $MODEL_IMAGE_HEIGHT
# adjust if past edge
if ($sx + $sw > $CAMERA_IMAGE_WIDTH) @ sx = $CAMERA_IMAGE_WIDTH - $sw
if ($sy + $sh > $CAMERA_IMAGE_HEIGHT) @ sy = $CAMERA_IMAGE_HEIGHT - $sh
@ rw = $sx + $sw
@ rh = $sy + $sh
# sensor box
set sensor = ( $sx $sy $rw $rh )
# transform (xform) to MODEL_IMAGE_WIDTH x MODEL_IMAGE_HEIGHT
set xform = "$sw"x"$sh"+"$sx"+"$sy"

###
### OUTPUT
###

/bin/echo "$motion" "$sensor" "$xform" "$CAMERA_IMAGE_WIDTH"x"$CAMERA_IMAGE_HEIGHT"

###
### DONE
###

done:
  if ($?DEBUG) /bin/echo "$0 ($$) -- FINISH" `date` >&! /dev/stderr
