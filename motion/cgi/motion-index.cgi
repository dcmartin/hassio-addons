#!/bin/tcsh
setenv APP "motion"
setenv API "index"

setenv DEBUG
setenv VERBOSE

if ($?TMP == 0) setenv TMP "/tmpfs"
if ($?LOGTO == 0) setenv LOGTO $TMP/$APP.log
if ($?DEBUG) echo `date` "$0:t $$ -- START" >>&! $LOGTO

# environment
if ($?MOTION_SHARE_DIR == 0) then
  set MOTION_SHARE_DIR = "/share/motion"
  if ($?DEBUG) echo `date` "$0:t $$ -- environment error: MOTION_SHARE_DIR undefined; using $MOTION_SHARE_DIR" >>&! $LOGTO
endif

###
### dateutils REQUIRED
###

if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/bin/dateconv ) then
   set dateconv = /usr/bin/dateconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  echo "No date converter; install dateutils" >& /dev/stderr
  exit 1
endif

# don't update statistics more than once per (in seconds)
set TTL = 1800
set SECONDS = `date "+%s"`
set DATE = `echo $SECONDS \/ $TTL \* $TTL | bc`
set AGE = `echo "$SECONDS - $DATE" | bc`

setenv COMPOSITE "__COMPOSITE__"

if ($?QUERY_STRING) then
    set noglob
    set DB = `echo "$QUERY_STRING" | sed 's/.*db=\([^&]*\).*/\1/'`
    if ("$DB" == "$QUERY_STRING") set DB = rough-fog
    set class = `echo "$QUERY_STRING" | sed 's/.*class=\([^&]*\).*/\1/'`
    if ("$class" == "$QUERY_STRING") unset class
    set id = `echo "$QUERY_STRING" | sed 's/.*id=\([^&]*\).*/\1/'`
    if ("$id" == "$QUERY_STRING") unset id
    set ext = `echo "$QUERY_STRING" | sed 's/.*ext=\([^&]*\).*/\1/'`
    if ("$ext" == "$QUERY_STRING") unset ext
    set display = `echo "$QUERY_STRING" | sed 's/.*display=\([^&]*\).*/\1/'`
    if ("$display" == "$QUERY_STRING") unset display
    set level = `echo "$QUERY_STRING" | sed 's/.*level=\([^&]*\).*/\1/'`
    if ("$level" == "$QUERY_STRING") unset level
    unset noglob
else
    echo `date` "$0:t $$ -- PLEASE SPECIFY QUERY_STRING" >>! $LOGTO
    exit
endif

if ($?DB) then
  set db = "$DB:h"
else
  set DB = rough-fog
  set db = "$DB"
endif

set DBt = ( "$DB:t" )
set dbt = ( "$db:t" ) 
if ($#dbt && $dbt != $db && $?class == 0) then
  set class = "$db:t"
  set db = "$db:h"
endif
if ($#DBt && $#dbt && $?id == 0) then
  set id = "$DB:t"
  set ide = ( $id:e )
  if ($#ide == 0) unset id
endif

## fix class to not include extraneous '/' and replace w/ urlencoded value '%2F'
if ($?class) then
  set class = ( `echo "$class" | sed 's@//@/@g' | sed 's@/$@@'` )
endif

if ($?db) then
    setenv QUERY_STRING "db=$db"
endif
if ($?ext) then
    setenv QUERY_STRING "$QUERY_STRING&ext=$ext"
endif
if ($?display) then
    setenv QUERY_STRING "$QUERY_STRING&display=$display"
endif
if ($?level) then
    setenv QUERY_STRING "$QUERY_STRING&level=$level"
endif
if ($?class) then
    setenv QUERY_STRING "$QUERY_STRING&class=$class"
endif
if ($?id) then
    setenv QUERY_STRING "$QUERY_STRING&id=$id"
endif

if ($?VERBOSE) echo `date` "$0:t $$ -- query string ($QUERY_STRING)" >>! $LOGTO

# check which image (ext = { full, crop } -> type = { jpg, jpeg } )
set type = "jpg"
if ($?ext) then
    set ext = $ext:h
    if ($ext == "crop") set type = "jpeg"
else
    set ext = "full"
endif

#
# handle images (files)
#
if ($?id) then
  set fid = "$id:r"
  if ("$fid" == "$id") then
    if ($?VERBOSE) echo `date` "$0:t $$ -- got directory $id ($class)" >>! $LOGTO
    set ext = "dir"
  else
    set id = "$fid"
  endif

    # do the normal thing to find the file with this ID (SLOOOOOOW)
    if ($ext != "dir") then
      set base = "$MOTION_SHARE_DIR/label/$db/$class"
      set images = ( `find "$base" -name "$id""*.$type" -type f -print | egrep -v "$COMPOSITE"` )
    else
      set base = "$MOTION_SHARE_DIR/label/$db/$class/$id"
      set images = ( `find "$base" -name "*.$type" -type f -print | egrep -v "$COMPOSITE"` )
    endif

    if ($?VERBOSE) echo `date` "$0:t $$ -- BASE ($base) ID ($id) images ($#images)" >>! $LOGTO

    if ($#images == 0) then
      echo "Status: 404 Not Found"
      goto done
    endif

    echo "Access-Control-Allow-Origin: *"
    echo "Age: $AGE"
    echo "Cache-Control: max-age=$TTL"
    echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`

    echo "Content-Location: /cgi-bin/$APP-$API.cgi?$QUERY_STRING"

    #  singleton image
    if ($#images == 1 && $ext != "dir") then
	echo "Content-Type: image/jpeg"
	echo ""
	if ($?VERBOSE) echo `date` "$0:t $$ -- SINGLETON ($id)" >>! $LOGTO
	dd if="$images"
    else if ($#images && $ext == "dir") then
	if ($?VERBOSE) echo `date` "$0:t $$ -- COMPOSITE IMAGES ($#images) " >>! $LOGTO
	set blend = "$base/$COMPOSITE.$type"
	if (-s "$blend") then
	  foreach i ( $images )
	    if (-M "$i" > -M "$blend") then
	    rm -f "$blend"
	    break
	  endif
       endif
       if (! -e "$blend") then
	if ($#images > 1) then
	    composite -blend 50 $images "$blend:r.$$.$blend:e"
	else
	    cp "$images" "$blend:r.$$.$blend:e"
	endif
	switch ($type)
 	  case "jpg": # 640x480 image
	    set csize = "600x40"
	    set psize = "48"
	    breaksw
	  case "jpeg": # 224x224 image
	    set csize = "200x20"
	    set psize = "18"
	    breaksw
	endsw
	# montage -label "$id" "$blend:r.$$.$blend:e" -pointsize 48 -frame 0 -geometry +10+10 "$blend"
        convert \
	  -pointsize "$psize" -size "$csize" \
	  xc:none -gravity center -stroke black -strokewidth 2 -annotate 0 \
	  "$id" \
	  -background none -shadow "100x3+0+0" +repage -stroke none -fill white -annotate 0 \
	  "$id" \
	  "$blend:r.$$.$blend:e" \
	  +swap -gravity south -geometry +0-3 -composite \
	  "$blend"
	/bin/rm -f "$blend:r.$$.$blend:e"
	if (! -s "$blend") then
	  if ($?DEBUG) echo `date` "$0:t $$ -- creation of composite image failed ($images)" >>! $LOGTO
	  set failure = "composite failure"
          goto done
	endif
      endif
      echo "Content-Type: image/jpeg"
      echo ""
      if ($?VERBOSE) echo `date` "$0:t $$ -- SINGLETON ($id)" >>! $LOGTO
      dd if="$blend"
    else
	#  trick is to use id to pass regexp base
	echo "Content-Type: application/zip"
	echo ""
	if ($?VERBOSE) echo `date` "$0:t $$ -- MULTIPLE IMAGES ZIP ($#images)" >>! $LOGTO
	zip - $images | dd of=/dev/stdout
    endif

    goto done
endif

#
# test hierarchy level (label/device/class); class could be a UNIX directory hierarchy, e.g. "/vehicle/car/sedan" (AFAIK :-)
#

if ($?class == 0) then
  # top-level
  set base = "$MOTION_SHARE_DIR/label/$db"
else 
  set base = "$MOTION_SHARE_DIR/label/$db/$class"
  if (-e "$base/.images.json") then
    if ((-M "$base/.images.json") < (-M "$base")) then
      rm -f "$base/.images.json"
    endif
  endif
  if (! -e "$base/.images.json") then
    # find all images in the $class directory
    if ($?VERBOSE) echo `date` "$0:t $$ -- FINDING IMAGES" >>! $LOGTO
    find "$base" -name "*.$type" -type f -print | egrep -v "$COMPOSITE" | sed "s@$base"".*/\(.*\)\.$type@\1@" >! "$base/.images.json"
  endif
  set images = ( `cat "$base/.images.json"` )
endif

# get subclasses
if (-e "$base/.classes.json") then
  if ((-M "$base/.classes.json") < (-M "$base")) then
    rm -f "$base/.classes.json"
  endif
endif
if (! -e "$base/.classes.json") then
  if ($?VERBOSE) echo `date` "$0:t $$ -- FINDING CLASSES" >>! $LOGTO
  find "$base" -name "[^\.]*" -type d -print | sed "s|$base||" | sed "s|^/||" >! "$base/.classes.json"
endif
set allsubdirs = ( `cat "$base/.classes.json"` )
foreach c ( $allsubdirs )
  if ("$c" == "$c:t") then
    if ($?classes) then
      set classes = ( $classes "$c" )
    else
      set classes = ( "$c" )
    endif
  endif
end 

#
# build HTML
#
if ($?display) then
  if ($?class) then
    set classid = ( `echo "$class" | sed "s@/@:@g"` )
    set OUTPUT = "$TMP/$0:t.$db.$classid.$ext.icon.html"
  else
    set OUTPUT = "$TMP/$0:t.$db.$ext.icon.html"
  endif
else
  if ($?class) then
    set classid = ( `echo "$class" | sed "s@/@:@g"` )
    set OUTPUT = "$TMP/$0:t.$db.$classid.$ext.html"
  else
    set OUTPUT = "$TMP/$0:t.$db.$ext.html"
  endif
endif

if (-s "$OUTPUT" && ((-M "$base") <= (-M "$OUTPUT"))) then
  if ($?VERBOSE) echo `date` "$0:t $$ -- CACHED ($OUTPUT)" >>! $LOGTO
  goto output
else
  rm -f "$OUTPUT"
endif

set MIXPANELJS = "/script/mixpanel-aah.js"

if ($?class) then
  if ($?VERBOSE) echo `date` "$0:t $$ -- BUILD ($class)" >>! $LOGTO
  # should make a path name
  set dir = "$db/$class"
  if ($?VERBOSE) echo `date` "$0:t $$ -- DIR ($dir)" >>! $LOGTO
  echo '<html><head><title>Index of '"$dir"'</title></head>' >! "$OUTPUT"
  echo '<script type="text/javascript" src="'$MIXPANELJS'"></script><script>mixpanel.track('"'"$APP-$API"'"',{"db":"'$db'","dir":"'$dir'"});</script>' >> "$OUTPUT"
  echo '<body bgcolor="white"><h1>Index of '"$dir"'</h1><hr>' >>! "$OUTPUT"
  if ($?display == 0) then
    echo '<pre>' >>! "$OUTPUT"
    set parent = "$class:h:h"
    if ($parent != "$class") then
      echo '<a href="/cgi-bin/'${APP}-${API}'.cgi?db='$db'&ext='$ext'&class='$parent'">../</a>' >>! "$OUTPUT"
    else
      echo '<a href="/cgi-bin/'${APP}-${API}'.cgi?db='$db'&ext='$ext'">../</a>' >>! "$OUTPUT"
    endif
  else # display icons for directories
    echo '<pre>' >>! "$OUTPUT"
    set parent = "$class:h:h"
    if ($parent != "$class") then
      echo '<a href="/cgi-bin/'${APP}-${API}'.cgi?db='$db'&ext='$ext'&display=icon&class='$parent'">../</a>' >>! "$OUTPUT"
    else
      echo '<a href="/cgi-bin/'${APP}-${API}'.cgi?db='$db'&ext='$ext'&display=icon">../</a>' >>! "$OUTPUT"
    endif
    echo '</pre>' >>! "$OUTPUT"
  endif
  if ($?classes) then
    if ($?VERBOSE) echo `date` "$0:t $$ -- SUBCLASSES ($classes)" >>! $LOGTO
    foreach i ( $classes )
      if ($?display) then
	echo '<a href="/cgi-bin/'${APP}-${API}'.cgi?db='"$db"'&ext='"$ext"'&display=icon&class='"$class/$i"'">' >>! "$OUTPUT"
	echo '<img width="24%" alt="'"$i"'" src="/cgi-bin/'${APP}-${API}'.cgi?db='"$db"'&ext='"$ext"'&class='"$class"'&id='"$i"'">' >>! "$OUTPUT"
	echo '</a>' >>! "$OUTPUT"
      else 
	set name = '<a href="/cgi-bin/'${APP}-${API}'.cgi?db='"$db"'&ext='"$ext"'&class='"$class/$i"'">'"$i"'/</a>'
	set ctime = `date '+%d-%h-%Y %H:%M'`
	set fsize = `du -sk "$MOTION_SHARE_DIR/label/$db/$class/$i" | awk '{ print $1 }'`
	echo "$name		$ctime		$fsize" >>! "$OUTPUT"
      endif
    end
  endif

  if ($?display) echo '<br>' >>! "$OUTPUT"

  if ($?VERBOSE) echo `date` "$0:t $$ -- HANDLING IMAGES ($#images)" >>! $LOGTO
  foreach i ( $images )
    if ($?display) then
      if (! $?classes) then
	echo '<a href="/cgi-bin/'$APP-$API'.cgi?db='"$db"'&ext='"$ext"'&class='"$class"'&id='"$i"'.'"$type"'">' >>! "$OUTPUT"
	echo '<img width="16%" alt="'"$i.$type"'" src="/cgi-bin/'$APP-$API'.cgi?db='"$db"'&ext='"$ext"'&class='"$class"'&id='"$i"'.'"$type"'">' >>! "$OUTPUT"
	echo '</a>' >>! "$OUTPUT"
      endif
    else
      set file = '<a href="/cgi-bin/'$APP-$API'.cgi?db='"$db"'&ext='"$ext"'&class='"$class"'&id='"$i"'.'"$type"'">'"$i.$type"'</a>' 
      set ctime = `date '+%d-%h-%Y %H:%M'`
      set fsize = `find "$MOTION_SHARE_DIR/label/$db/$class" -name "$i.$type" -print | xargs ls -l | awk '{ print $5 }'`
      echo "$file		$ctime		$fsize" >>! "$OUTPUT"
    endif
  end
  if ($?display == 0) then
    echo '</pre>' >>! "$OUTPUT"
  endif
  echo '<hr></body></html>' >>! "$OUTPUT"
  if ($?VERBOSE) echo `date` "$0:t $$ -- DONE" >>! $LOGTO
else if ($?classes) then
  if ($?VERBOSE) echo `date` "$0:t $$ -- BUILD ($classes)" >>! $LOGTO
    # should be a directory listing of directories
    set dir = "$db"
    echo '<html><head><title>Index of '"$dir"'/</title></head>' >! "$OUTPUT"
    echo '<script type="text/javascript" src="'$MIXPANELJS'"></script><script>mixpanel.track('"'"$APP-$API"'"',{"db":"'$db'"});</script>' >> "$OUTPUT"
    echo '<body bgcolor="white"><h1>Index of '"$dir"'</h1><hr>' >>! "$OUTPUT"
    echo '<pre>' >>! "$OUTPUT"
    if ($?display) then
      echo '<a href="/cgi-bin/'$APP-$API'.cgi?db='$db'&ext='$ext'/">../</a>' >>! "$OUTPUT"
      echo '</pre>' >>! "$OUTPUT"
    else
      echo '<a href="/cgi-bin/'$APP-$API'.cgi?db='$db'&ext='$ext'&display=icon/">../</a>' >>! "$OUTPUT"
    endif
    foreach i ( $classes )
      if ($?display == 0) then
	set name = '<a href="/cgi-bin/'$APP-$API'.cgi?db='"$db"'&ext='"$ext"'&class='"$i"'/">'"$i"'/</a>' >>! "$OUTPUT"
	set ctime = `date '+%d-%h-%Y %H:%M'`
	set fsize = `du -sk "$MOTION_SHARE_DIR/label/$db/$i" | awk '{ print $1 }'`
	echo "$name		$ctime		$fsize" >>! "$OUTPUT"
      else
	echo '<a href="/cgi-bin/'$APP-$API'.cgi?db='"$db"'&ext='"$ext"'&display=icon&class='"$i"'">' >>! "$OUTPUT"
	echo '<img width="24%" alt="'"$i"'" src="/cgi-bin/'$APP-$API'.cgi?db='"$db"'&ext='"$ext"'&class=&id='"$i"'">' >>! "$OUTPUT"
	echo '</a>' >>! "$OUTPUT"
      endif
    end
    if ($?display == 0) then
      echo '</pre>' >>! "$OUTPUT"
    endif
    echo '<hr></body></html>' >>! "$OUTPUT"
endif

output:

echo "Access-Control-Allow-Origin: *"
echo "Age: $AGE"
echo "Cache-Control: max-age=$TTL"
echo "Last-Modified:" `$dateconv -i '%s' -f '%a, %d %b %Y %H:%M:%S %Z' $DATE`
echo "Content-Type: text/html"
# echo "Content-Location: $HTTP_HOST/cgi-bin/$APP-$API.cgi?$QUERY_STRING"
echo ""

cat "$OUTPUT"

done:

if ($?DEBUG) echo `date` "$0:t $$ -- FINISH" >>&! $LOGTO
