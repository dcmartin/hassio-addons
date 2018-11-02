#!/bin/tcsh

setenv DEBUG true

if ($?CONFIG_PATH == 0) setenv CONFIG_PATH /data/options.json

AAHDIR=$(jq -r ".aahdir" $CONFIG_PATH)
if ($?DEBUG) echo "AAH directory ${AAHDIR}"

BASE_URL=$(jq -r ".base_url" $CONFIG_PATH)
if ($?DEBUG) echo "Base URL ${BASE_URL}"

CLOUDANT_URL=$(jq -r ".cloudant.url" $CONFIG_PATH)
CLOUDANT_USERNAME=$(jq -r ".cloudant.username" $CONFIG_PATH)
CLOUDANT_PASSWORD=$(jq -r ".cloudant.password" $CONFIG_PATH)
if ($?DEBUG) echo "Cloudant setup ${CLOUDANT_URL}, ${CLOUDANT_USERNAME}, ${CLOUDANT_PASSWORD}"

WATSON_VR_URL=$(jq -r ".watson.vr_url" $CONFIG_PATH)
WATSON_VR_APIKEY=$(jq -r ".watson.vr_apikey" $CONFIG_PATH)
WATSON_VR_VERSION=$(jq -r ".watson.vr_version" $CONFIG_PATH)
WATSON_VR_DATE=$(jq -r ".watson.vr_date" $CONFIG_PATH)
if ($?DEBUG) echo "Watson Visual Recognition setup ${WATSON_VR_URL}, ${WATSON_VR_APIKEY}, ${WATSON_VR_VERSION}, ${WATSON_VR_DATE}"

if ($?DEBUG) echo "Starting Apache"

/usr/local/apache2/bin/apachectl -f /usr/local/apache2/conf/httpd.conf

rc-service apache2 start

mosquitto_sub -h 192.168.1.40 -t 'motion/#' >& /dev/stderr
