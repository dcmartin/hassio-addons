#!/bin/bash
echo "+++ BEGIN: $0: $*" $(date) >&2

# get arguments
EVENT=$1
IMAGE_FILE=$2
IMAGE_TYPE=$3
MOTION_MIDX=$4
MOTION_MIDY=$5
MOTION_WIDTH=$6
MOTION_HEIGHT=$7

if [ -z "${IMAGE_FILE}" ]; then
  echo "<EVENT> <IMAGE_FILE> <IMAGE_TYPE> <MIDX> <MIDY> <WIDTH> <HEIGHT>"
  exit
fi

# X coordinate in pixels of the center point of motion. Origin is upper left corner.
# Y coordinate in pixels of the center point of motion. Origin is upper left corner and number is positive moving downwards 

# calculate imagebox
MOTION_X=$(/bin/echo "${MOTION_MIDX} - ( ${MOTION_WIDTH} / 2 )" | /usr/bin/bc)
MOTION_Y=$(/bin/echo "${MOTION_MIDY} - ( ${MOTION_HEIGHT} / 2 )" | /usr/bin/bc)

IMAGE_BOX="${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}"

/bin/echo "+++ $0 PROCESSING ${EVENT} ${IMAGE_ID} ${MOTION_MIDX} ${MOTION_MIDY} ${MOTION_WIDTH} ${MOTION_HEIGHT} == ${IMAGE_BOX}"

#
# Prepare output
#
OUTPUT="${IMAGE_FILE%.*}.json"
# drop prefix path
IMAGE_ID=`echo "${OUTPUT##*/}"`
# drop extension
IMAGE_ID=`echo "${IMAGE_ID%.*}"`

# create VR_OUTPUT JSON filename
VR_OUTPUT="${IMAGE_FILE%.*}-vr.json"
# proceed iff all
if [ -z "${VR_OFF}" ] && [ -n "${VR_APIKEY}" ] && [ -n "${VR_VERSION}" ] && [ -n "${VR_DATE}" ] && [ -n "${VR_URL}" ]; then
    if [ -z "${VR_CLASSIFIER}" ]; then
	VR_CLASSIFIER="default"
    else
	# custom classifier goes first; top1 from first classifier is encoded as alchemy
        VR_CLASSIFIER="${VR_CLASSIFIER},default"
    fi
    echo "+++ $0 PROCESSING visual-recognition ${VR_CLASSIFIER} ${VR_VERSION} ${VR_DATE} ${VR_URL} ${IMAGE_FILE}"
    # make the call
    curl -s -q -L \
        --header "X-Watson-Learning-Opt-Out: true" \
        -F "images_file=@$IMAGE_FILE" \
	-o "${VR_OUTPUT}" \
	"$VR_URL/$VR_VERSION/classify?api_key=$VR_APIKEY&classifier_ids=$VR_CLASSIFIER&threshold=0.0&version=$VR_DATE"
    if [ -s "${VR_OUTPUT}" ]; then
	echo  "+++ $0 SUCCESS visual-recognition ${IMAGE_FILE}"
    else
	echo "+++ $0 FAILURE visual-recognition ${IMAGE_FILE}"
    fi
else
    echo "+++ $0 VISUAL-RECOGNITION - OFF"
fi

#
# DIGITS
#
# EXAMPLE
# {"predictions":[["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=road",90.09],["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=motorcycle",9.76],["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=car",0.06],["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=builder",0.03],["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=martin c70",0.02]]}

# create DG_OUTPUT JSON filename
DG_OUTPUT="${IMAGE_FILE%.*}-dg.json"
if [ -n "${DIGITS_SERVER_URL}" ]; then
    if [ -n "${DIGITS_JOB_ID}" ]; then
	CMD="models/images/classification/classify_one.json"
	# get inference
        echo "+++ $0 PROCESSING DIGITS (${DIGITS_JOB_ID})"
	curl -s -q -L -X POST \
	    -F "image_file=@$IMAGE_FILE" \
	    -F "job_id=${DIGITS_JOB_ID}" \
	    -o "${DG_OUTPUT}" \
	    "${DIGITS_SERVER_URL}/${CMD}"
	# debug
	if [ -s "${DG_OUTPUT}" ]; then
	    jq -c '.predictions[]' "${DG_OUTPUT}" \
	    	| sed 's/.*http.*class=\([^"]*\)",\(.*\)\]/\1,'"$DIGITS_JOB_ID"',\2/' \
		| sed 's/ /_/g' \
		| awk -F, 'BEGIN { n=0 } { if (n>0) printf(","); n++; printf("{\"classifier_id\":\"%s\",\"name\":\"%s\",\"score\":%1.4f}", $1, $2, $3/100)}' > "${DG_OUTPUT}.$$"
	    mv "${DG_OUTPUT}.$$" "${DG_OUTPUT}"
            echo "+++ $0 SUCCESS DIGITS (${DIGITS_JOB_ID})"
        else
            echo "+++ $0 FAILURE DIGITS (${DIGITS_JOB_ID})"
	fi
    else
	echo "+++ $0 NO DIGITS_JOB_ID specified for server ${DIGITS_SERVER_URL}"
    fi
else
    echo "+++ $0 NO DIGITS_SERVER_URL specified"
fi

#
# CREATE OUTPUT FROM COMBINATIONS OF RESULTS
#

if [ -s "${VR_OUTPUT}" ]; then
    echo "+++ $0 PROCESSING VISUAL_RECOGNITION ${VR_OUTPUT}"
    # encode top1 across custom (iff specified above) and default classifiers; decorate with source: default, <hierarchy:default>, custom classifier_id
    jq -c \
      '[.images[0]|.classifiers[]|.classifier_id as $cid|.classes|sort_by(.score)[-1]|{text:.class,name:(if .type_hierarchy == null then $cid else .type_hierarchy end),score:.score}]|sort_by(.score)[-1]' \
      "${VR_OUTPUT}" > "${OUTPUT}.alchemy.$$"
    # process WVR into "market basket" with "name" used to indicate source (default, <custom-id> or hierarchy (from default)
    jq -c \
      '.images[0]|{image:.image,scores:[.classifiers[]|.classifier_id as $cid|.classes[]|{classifier_id:.class,name:(if .type_hierarchy == null then $cid else .type_hierarchy end),score:.score}]}' \
      "${VR_OUTPUT}" > "${OUTPUT}.visual.$$"
    # test if DIGITS too
    if [ -s "${DG_OUTPUT}" ]; then
	echo "+++ $0 ADDING WATSON & DIGITS classifiers"
	sed 's/\(.*\)/{"alchemy":\1,"visual":/' "${OUTPUT}.alchemy.$$" | paste - "${OUTPUT}.visual.$$" | sed 's/]}$/,/' | paste - "${DG_OUTPUT}" | sed 's/$/]}}/' > "${OUTPUT}.$$"
    else
	echo "+++ $0 ADDING WATSON WITH ALCHEMY AS TOP1 ACROSS DEFAULT & ANY CUSTOM CLASSIFIER"
        # concatenate -- "alchemy" is _really_ "top1" and "visual" is _really_ the entire "set" of classifiers
	sed 's/\(.*\)/{"alchemy":\1,"visual":/' "${OUTPUT}.alchemy.$$" | paste - "${OUTPUT}.visual.$$" | sed 's/]}$/]}}/' > "${OUTPUT}.$$"
    fi
    # process consolidated scores into sorted list
    if [ -s "${DG_OUTPUT}" ]; then
	echo "+++ $0 REPLACING ALCHEMY WITH TOP1 ACROSS WATSON & DIGITS"
        # pick top1 across all classification results; sorted by score
        TOP1=$(jq -r '.visual.scores|sort_by(.score)[-1]|{"text":.classifier_id,"name":.name,"score":.score}' "${OUTPUT}.$$")
	# change output to indicate (potentially) new top1
	cat "${OUTPUT}.$$" | jq '.alchemy='"${TOP1}" > "$OUTPUT.$$.$$"
	if [ -s "$OUTPUT.$$.$$" ]; then
	  mv "${OUTPUT}.$$.$$" "${OUTPUT}.$$"
	fi
	rm -f "${OUTPUT}.$$.$$"
    fi
    # create (and validate) output
    jq -c '.' "${OUTPUT}.$$" > "${OUTPUT}"
    # cleanup
    rm -f "${OUTPUT}.alchemy.$$" "${OUTPUT}.visual.$$"
elif [ -s "${DG_OUTPUT}" ]; then
    echo "+++ $0 PROCESSING ${DG_OUTPUT} ONLY"
    TOP1=$(echo '[' | paste - "${DG_OUTPUT}" | sed 's/$/]/' | jq '.|sort_by(.score)[-1]|{"text":.classifier_id,"name":.name,"score":.score}')
    CLASSIFIERS=$(echo '[' | paste - "${DG_OUTPUT}" | sed 's/$/]/' | jq '.|sort_by(.score)')
    echo '{"alchemy":'"${TOP1}"',"visual":{"image":"'"${IMAGE_ID}.jpg"'","scores":{"classifiers":'"${CLASSIFIERS}"'}}}' >! "${OUTPUT}"
else
    echo "+++ $0 NO OUTPUT"
    echo '{ "alchemy":{"text":"NA","name":"NA","score":0},' > "${OUTPUT}.$$"
    echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"NA","name":"NA","score":0}]' >> "${OUTPUT}.$$"
    echo '}}' >> "${OUTPUT}"
fi

# debug
jq -c '.' "${OUTPUT}"

# remove tmp & originals
rm -f "${OUTPUT}.$$" "${VR_OUTPUT}" "${DG_OUTPUT}"

#
# add date and time
#
if [ -s "${OUTPUT}" ]; then
    # add datetime and bounding box information
    if [ -n "${IMAGE_ID}" ] && [ -n "${IMAGE_BOX}" ]; then
	DATE_TIME=`echo "${IMAGE_ID}" | sed "s/\(.*\)-.*-.*/\1/"`
	YEAR=`echo "${DATE_TIME}" | sed "s/^\(....\).*/\1/"`
	MONTH=`echo "${DATE_TIME}" | sed "s/^....\(..\).*/\1/"`
	DAY=`echo "${DATE_TIME}" | sed "s/^......\(..\).*/\1/"`
	HOUR=`echo "${DATE_TIME}" | sed "s/^........\(..\).*/\1/"`
	MINUTE=`echo "${DATE_TIME}" | sed "s/^..........\(..\).*/\1/"`
	SECOND=`echo "${DATE_TIME}" | sed "s/^............\(..\).*/\1/"`

	# should think more about adding the event gap specification into the event record -- and maybe the date (in seconds since epoch)
	    # sed 's/^{/{"year":"YEAR","month":"MONTH","day":"DAY","hour":"HOUR","minute":"MINUTE","second":"SECOND","eventgap":"MOTION_EVENT_GAP","imagebox":"IMAGE_BOX",/' | \
            # sed "s/MOTION_EVENT_GAP/${MOTION_EVENT_GAP}/" | \
	cat "${OUTPUT}" | \
	    sed 's/^{/{"year":"YEAR","month":"MONTH","day":"DAY","hour":"HOUR","minute":"MINUTE","second":"SECOND","imagebox":"IMAGE_BOX",/' | \
	    sed "s/YEAR/${YEAR}/" | \
	    sed "s/MONTH/${MONTH}/" | \
	    sed "s/DAY/${DAY}/" | \
	    sed "s/HOUR/${HOUR}/" | \
	    sed "s/MINUTE/${MINUTE}/" | \
	    sed "s/SECOND/${SECOND}/" | \
	    sed "s/DAY/${DAY}/" | \
	    sed "s/IMAGE_BOX/${IMAGE_BOX}/" > /tmp/OUTPUT.$$
	mv /tmp/OUTPUT.$$ "${OUTPUT}"
    fi
else
    echo "*** ERROR: $0 - NO OUTPUT"
    exit
fi

#
# CLOUDANT
#

if [ -z "${CLOUDANT_OFF}" ] && [ -s "${OUTPUT}" ] && [ -n "${CLOUDANT_URL}" ] && [ -n "${DEVICE_NAME}" ]; then
    DEVICE_DB=`curl -q -s -X GET "${CLOUDANT_URL}/${DEVICE_NAME}" | jq '.db_name'`
    if [ "${DEVICE_DB}" == "null" ]; then
	# create DB
	DEVICE_DB=`curl -q -s -X PUT "${CLOUDANT_URL}/${DEVICE_NAME}" | jq '.ok'`
	# test for success
	if [ "${DEVICE_DB}" != "true" ]; then
	    # failure
	    CLOUDANT_OFF=TRUE
        fi
    fi
    if [ -z "${CLOUDANT_OFF}" ]; then
	curl -q -s -H "Content-type: application/json" -X PUT "$CLOUDANT_URL/${DEVICE_NAME}/${IMAGE_ID}" -d "@${OUTPUT}"
    fi
else
    echo "+++ $0 NO CLOUDANT (CHECK DEVICE_NAME)"
fi

# make a noise
if [ -z "${TALKTOME_OFF}" ] && [ -s "${OUTPUT}" ] && [ -n "${WATSON_TTS_URL}" ] && [ -n "${WATSON_TTS_CREDS}" ]; then
    # what entity to discuss/say
    WHAT=`jq -j '.alchemy.text' "${OUTPUT}"`
    # should be a lookup aah_whatToSay(<where>,<when>,[<entity>],<whom>?)
    if [ -z "${WHAT_TO_SAY}" ]; then
	SPEAK="I just saw ${WHAT}"
    else
	SPEAK="${WHAT_TO_SAY} ${WHAT}"
    fi
    if [ ! -f "${WHAT}.wav" ]; then
	curl -s -q -L -X POST \
	  --header "Content-Type: application/json" \
	  --header "Accept: audio/wav" \
	  --data '{"text":"'"${SPEAK}"'"}' \
	  "https://${WATSON_TTS_CREDS}@${WATSON_TTS_URL}?voice=en-US_MichaelVoice" --output "${WHAT}.wav"
    fi
    play "${WHAT}.wav"
fi

# send an email
if [ -n "${EMAILME_ON}" ] && [ -s "${OUTPUT}" ] && [ -n "${GMAIL_ACCOUNT}" ] && [ -n "${GMAIL_CREDS}" ] && [ -n "${EMAIL_ADDRESS}" ]; then
    if [ ! -f "${WHAT}.txt" ]; then
        echo "From: ${AAH_LOCATION}" > "${WHAT}.txt"
        echo "Subject: ${WHAT}" >> "${WHAT}.txt"
    fi
    curl -v --url 'smtps://smtp.gmail.com:465' --ssl-reqd --mail-from "${GMAIL_ACCOUNT}" --mail-rcpt "${EMAIL_ADDRESS}" --upload-file "${WHAT}.txt" --user "${GMAIL_CREDS}" --insecure
    rm -f "${WHAT}.txt"
fi

# post json to MQTT
if [ -n "${MQTT_ON}" ] && [ -s "${OUTPUT}" ] && [ -n "${MQTT_HOST}" ]; then
    CLASS=`jq -r '.alchemy.text' "${OUTPUT}" | sed 's/ /_/g'`
    MODEL=`jq -r '.alchemy.name' "${OUTPUT}" | sed 's/ /_/g'`
    SCORE=`jq -r '.alchemy.score' "${OUTPUT}"`

    if [ -z "${MQTT_TOPIC}" ]; then
        MQTT_TOPIC='presence/'"${AAH_LOCATION}"
    fi
    # what entity to discuss/say
    if [ ! -z "${MQTT_JQUERY}" ]; then
        WHAT=`jq -r "${MQTT_JQUERY}" "${OUTPUT}"`
    else
	WHAT='"class":"'"${CLASS}"'","model":"'"${MODEL}"'","score":'"${SCORE}"',"id":"'"${IMAGE_ID}"'"'
    fi
    MSG='{"device":"'"${DEVICE_NAME}"'","location":"'"${AAH_LOCATION}"'","date":'`date +%s`','"${WHAT}"'}'
    mosquitto_pub -i "${DEVICE_NAME}" -r -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -m "${MSG}"
fi

# post image to MQTT
if [ -n "${MQTT_ON}" ] && [ -s "${IMAGE_FILE}" ] && [ -n "${MQTT_HOST}" ]; then
  MQTT_TOPIC='image/'"${AAH_LOCATION}"

  mosquitto_pub -i "${DEVICE_NAME}" -r -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${IMAGE_FILE}"
fi

# post annotated image to MQTT
if [ -n "${MQTT_ON}" ] && [ -s "${IMAGE_FILE}" ] && [ -s "${OUTPUT}" ] && [ -n "${MQTT_HOST}" ]; then
  CLASS=`jq -r '.alchemy.text' "${OUTPUT}" | sed 's/ /_/g'`
  MODEL=`jq -r '.alchemy.name' "${OUTPUT}" | sed 's/ /_/g'`
  SCORE=`jq -r '.alchemy.score' "${OUTPUT}"`
  CROP=`jq -r '.imagebox' "${OUTPUT}"`

  #
  # CODE FROM aah-images-label.csh
  #
  image-annotate.csh "${IMAGE_FILE}" "${CLASS}" "${CROP}" > "${IMAGE_FILE}.$$"

  if [ -s "${IMAGE_FILE}.$$" ]; then
    MQTT_TOPIC='image-annotated/'"${AAH_LOCATION}"
    mosquitto_pub -i "${DEVICE_NAME}" -r -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${IMAGE_FILE}.$$"
    rm -f "${IMAGE_FILE}.$$"
  fi
  if [ -s "${IMAGE_FILE%.*}.jpeg" ]; then
    MQTT_TOPIC='image-cropped/'"${AAH_LOCATION}"
    mosquitto_pub -i "${DEVICE_NAME}" -r -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${IMAGE_FILE%.*}.jpeg"
    rm -f "${IMAGE_FILE%.*}.jpeg"
  fi
fi

# force image updates periodically (15 minutes; 1800 seconds)
if [ -n "${AAH_LAN_SERVER}" ]; then
  TTL=1800
  SECONDS=$(date "+%s")
  DATE=$(/bin/echo "${SECONDS} / ${TTL} * ${TTL}" | bc)
  if [ ! -f "/tmp/images.$DATE.json" ]; then
    rm -f "/tmp/images".*.json
    curl "http://${AAH_LAN_SERVER}/CGI/aah-images.cgi?db=${DEVICE_NAME}" > "/tmp/images.${DATE}.json"
    jq -c '.' "/tmp/images.${DATE}.json"
  fi
fi
echo "+++ END: $0: $*" $(date) >&2
