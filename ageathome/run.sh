#!/bin/bash

DEBUG=true

CONFIG_PATH=/data/options.json

TMP=$(jq --raw-output ".temporary_dir" $CONFIG_PATH)
if ($?DEBUG) echo "Temporary directory ${TMP}"

BASE_URL=$(jq --raw-output ".base_url" $CONFIG_PATH)
if ($?DEBUG) echo "Base URL ${BASE_URL}"

CLOUDANT_URL=$(jq --raw-output ".cloudant_url" $CONFIG_PATH)
CLOUDANT_USERNAME=$(jq --raw-output ".cloudant_username" $CONFIG_PATH)
CLOUDANT_PASSWORD=$(jq --raw-output ".cloudant_password" $CONFIG_PATH)
if ($?DEBUG) echo "Cloudant setup ${CLOUDANT_URL}, ${CLOUDANT_USERNAME}, ${CLOUDANT_PASSWORD}"

WATSON_VR_URL=$(jq --raw-output ".watson_vr_url" $CONFIG_PATH)
WATSON_VR_APIKEY=$(jq --raw-output ".watson_vr_apikey" $CONFIG_PATH)
WATSON_VR_VERSION=$(jq --raw-output ".watson_vr_version" $CONFIG_PATH)
WATSON_VR_DATE=$(jq --raw-output ".watson_vr_date" $CONFIG_PATH)
if ($?DEBUG) echo "Watson Visual Recognition setup ${WATSON_VR_URL}, ${WATSON_VR_APIKEY}, ${WATSON_VR_VERSION}, ${WATSON_VR_DATE}"




nginx -g "daemon off;"
