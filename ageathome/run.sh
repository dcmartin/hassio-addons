#!/bin/bash

DEBUG=true

CONFIG_PATH=/data/options.json

AAHDIR=$(jq --raw-output ".aahdir" $CONFIG_PATH)
if ($?DEBUG) echo "AAH directory ${AAHDIR}"

BASE_URL=$(jq --raw-output ".base_url" $CONFIG_PATH)
if ($?DEBUG) echo "Base URL ${BASE_URL}"

CLOUDANT_URL=$(jq --raw-output ".cloudant.url" $CONFIG_PATH)
CLOUDANT_USERNAME=$(jq --raw-output ".cloudant.username" $CONFIG_PATH)
CLOUDANT_PASSWORD=$(jq --raw-output ".cloudant.password" $CONFIG_PATH)
if ($?DEBUG) echo "Cloudant setup ${CLOUDANT_URL}, ${CLOUDANT_USERNAME}, ${CLOUDANT_PASSWORD}"

WATSON_VR_URL=$(jq --raw-output ".watson.vr_url" $CONFIG_PATH)
WATSON_VR_APIKEY=$(jq --raw-output ".watson.vr_apikey" $CONFIG_PATH)
WATSON_VR_VERSION=$(jq --raw-output ".watson.vr_version" $CONFIG_PATH)
WATSON_VR_DATE=$(jq --raw-output ".watson.vr_date" $CONFIG_PATH)
if ($?DEBUG) echo "Watson Visual Recognition setup ${WATSON_VR_URL}, ${WATSON_VR_APIKEY}, ${WATSON_VR_VERSION}, ${WATSON_VR_DATE}"

if ($?DEBUG) echo "Starting Apache"

/usr/local/apache2/bin/apachectl -f /usr/local/apache2/conf/httpd.conf

rc-service apache2 start

sleep 1800
