#!/bin/bash

# location of configuration file
CONFIG_PATH=/data/options.json

# configuration
CONFIG=$(jq -r ".config" $CONFIG_PATH)
if [ -n "${CONFIG}" ] && [ -e "${CONFIG}" ]; then
  JSON='{"config":"'"${CONFIG}"'"'
else
  echo "Cannot determine configuration; exiting"
  exit
fi

# data
DATA=$(jq -r ".data" $CONFIG_PATH)
if [ -n "${DATA}" ] && [ -e "${DATA}" ]; then
  JSON=',"data":"'"${DATA}"'"'
else
  echo "Cannot determine data; exiting"
  exit
fi

# path
PROJECTS=$(jq -r ".path" $CONFIG_PATH)
if [ -n "${PROJECTS}" ] && [ -e "${PROJECTS}" ]; then
  JSON=',"path":"'"${PROJECTS}"'"}'
else
  echo "Cannot determine path; exiting"
  exit
fi

python -m rasa_nlu.train \
    --config "${CONFIG}" \
    --data "${DATA}" \
    --path "${PROJECTS}"

python -m rasa_nlu.server --path "${PROJECTS}"
