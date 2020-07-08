#!/bin/bash

###
## FUNCTIONS
###

## configuration
config()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local VALUE
  local JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'$(hostname -i)'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)

  ## time zone
  VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
    VALUE="GMT"
    bashio::log.warn "timezone unspecified; defaulting to ${VALUE}"
  fi
  if [ -s "/usr/share/zoneinfo/${VALUE:-null}" ]; then
    cp /usr/share/zoneinfo/${VALUE} /etc/localtime
    echo "${VALUE}" > /etc/timezone
    bashio::log.info "TIMEZONE: ${VALUE}"
  else
    bashio::log.error "No known timezone: ${VALUE}"
  fi
  JSON="${JSON}"',"timezone":"'"${VALUE}"'"'
  # unit_system
  VALUE=$(jq -r '.unit_system' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
  bashio::log.info "Set unit_system to ${VALUE}"
  JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'
  # latitude
  VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
  bashio::log.info "Set latitude to ${VALUE}"
  JSON="${JSON}"',"latitude":'"${VALUE}"
  # longitude
  VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
  bashio::log.info "Set longitude to ${VALUE}"
  JSON="${JSON}"',"longitude":'"${VALUE}"
  # elevation
  VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
  bashio::log.info "Set elevation to ${VALUE}"
  JSON="${JSON}"',"elevation":'"${VALUE}"
  
  ## MQTT
  # host
  VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
  bashio::log.info "Using MQTT at ${VALUE}"
  MQTT='{"host":"'"${VALUE}"'"'
  # username
  VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  bashio::log.info "Using MQTT username: ${VALUE}"
  MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
  # password
  VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  bashio::log.info "Using MQTT password: ${VALUE}"
  MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
  # port
  VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
  bashio::log.info "Using MQTT port: ${VALUE}"
  MQTT="${MQTT}"',"port":'"${VALUE}"'}'
  
  ## finish
  JSON="${JSON}"',"mqtt":'"${MQTT}"'}'

  echo "${JSON:-null}"
}

###
## UPDATE
###

ambianic::update.sources.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local video="${*}"
  local name=$(echo "${video:-null}" | jq -r '.name')
  local type=$(echo "${video:-null}" | jq -r '.type')
  local uri=$(echo "${video:-null}" | jq -r '.uri')
  local live=$(echo "${video:-null}" | jq -r '.live')

  echo '  '${name}': &'${name}
  echo '    uri: '${uri}
  echo '    type: '${type}
  echo '    live: '${live}
}

ambianic::update.sources()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local sources=$(echo "${config}" | jq '.sources')

  if [ "${sources:-null}" != 'null' ]; then
    local nsource=$(echo "${sources}" | jq '.|length')

    i=0; while ${i} -lt ${nsource}; do
      local source=$(echo "${sources}" | jq -c '.['${i}']')

      if [ "${source:-null}" != 'null' ]; then
        local type=$(echo "${source}" | jq -r '.type')
        local src='null'

        case ${type:-null} in
          video)
            ambianic::update.sources.video "${source}"
            ;;
          *)
            bashio::log.warn "Invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
    srcs="${srcs}]"
    bashio::log.debug "Sources: ${srcs}"
    result=${srcs}
  else
    bashio::log.notice "No sources defined; configuration:" $(echo "${config:-null}" | jq -c '.')
  fi
}

ambianic::update.ai_models()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local ai_models=$(echo "${config}" | jq '.ai_models')

  if [ "${ai_models:-null}" != 'null' ]; then
    local nai_model=$(echo "${ai_models}" | jq '.|length')

    i=0; while ${i} -lt ${nai_model}; do
      local ai_model=$(echo "${ai_models}" | jq -c '.['${i}']')

      if [ "${ai_model:-null}" != 'null' ]; then
        local type=$(echo "${ai_model}" | jq -r '.type')
        local src='null'

        case ${type:-null} in
          video)
            ambianic::update.sources.video "${ai_model}"
            ;;
          *)
            bashio::log.warn "Invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
    srcs="${srcs}]"
    bashio::log.debug "Sources: ${srcs}"
    result=${srcs}
  else
    bashio::log.notice "No ai_models defined; configuration:" $(echo "${config:-null}" | jq -c '.')
  fi
}

ambianic::update.pipelines()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local pipelines=$(echo "${config}" | jq '.pipelines')

  if [ "${pipelines:-null}" != 'null' ]; then
    local npipeline=$(echo "${pipelines}" | jq '.|length')

    i=0; while ${i} -lt ${npipeline}; do
      local pipeline=$(echo "${pipelines}" | jq -c '.['${i}']')

      if [ "${pipeline:-null}" != 'null' ]; then
        local type=$(echo "${pipeline}" | jq -r '.type')
        local src='null'

        case ${type:-null} in
          video)
            ambianic::update.sources.video "${pipeline}"
            ;;
          *)
            bashio::log.warn "Invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
    srcs="${srcs}]"
    bashio::log.debug "Sources: ${srcs}"
    result=${srcs}
  else
    bashio::log.notice "No pipelines defined; configuration:" $(echo "${config:-null}" | jq -c '.')
  fi
}

ambianic::update()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"

  ambianic::update.ai_modles >> ${AMBIANIC_CONFIG}
  ambianic::update.sources >> ${AMBIANIC_CONFIG}
  ambianic::update.pipelines >> ${AMBIANIC_CONFIG}
}

###
## CONFIGURE
###

ambianc::config.sources.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local video="${*}"
  local result
  local name=$(echo "${video:-null}" | jq -r '.name')

  if [ "${name-null}" != 'null' ]; then
    bashio::log.debug "Name: ${name}"
    local uri=$(echo "${video:-null}" | jq -r '.uri')
    if [ "${uri-null}" != 'null' ]; then
      local type=$(echo "${video:-null}" | jq -r '.type')
      if [ "${type-null}" != 'null' ]; then
        bashio::log.debug "Type: ${type}"
        local live=$(echo "${video:-null}" | jq '.live==true')
        if [ "${type-null}" != 'null' ]; then
          bashio::log.debug "Live: ${live}"

          result='{"name":"'${name}'","uri":"'${uri}'",,"type":"'${type}'","live":'${live}'}'
        else
          bashio::log.info "Live unspecified: ${video}"
        fi
      else
        bashio::log.info "Type unspecified: ${video}"
      fi
    else
      bashio::log.info "URI unspecified: ${video}"
    fi
  else
    bashio::log.info "Name unspecified: ${video}"
  fi

  echo ${result:-null}
}

ambianic::config.sources()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"
  
  local cpath=${1:-${CONFIG_PATH}}
  local cameras=$(jq '.cameras' ${cpath})
  local result
  local srcs='['

  if [ "${cameras:-null}" != 'null' ]; then
    local ncamera=$(echo "${cameras}" | jq '.|length')

    i=0; j=0; while ${i} -lt ${ncamera}; do
      local camera=$(echo "${cameras}" | jq -c '.['${i}']')

      if [ "${camera:-null}" != 'null' ]; then
        local type=$(echo "${camera}" | jq -r '.type')
        local src='null'

        case ${type:-null} in
          video)
            src=$(ambianic::config.sources.video "${camera}")
            if [ "${src:-null}" = 'null' ]; then
              bashio::log.warn "FAILED to source video ${i}: ${video}"
            else
              bashio::log.debug "Sourced video ${i}: ${src}"
              if [ ${j} -gt 0 ]; then srcs="${srcs},"; fi
                srcs="${srcs}${src}"
              fi
              j=$((j+1))
            fi
            ;;
          *)
            bashio::log.warn "Invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
    srcs="${srcs}]"
    bashio::log.debug "Sources: ${srcs}"
    result=${srcs}
  else
    bashio::log.notice "No cameras defined; configuration: ${cpath}"
  fi
  echo ${result:-null}
}

#ai_models:
#  image_detection: &tfm_image_detection
#    model:
#      tflite: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_coco_quant_postprocess.tflite
#      edgetpu: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_coco_quant_postprocess_edgetpu.tflite
#    labels: /opt/ambianic-edge/ai_models/coco_labels.txt
#  face_detection: &tfm_face_detection
#    model:
#      tflite: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_face_quant_postprocess.tflite
#      edgetpu: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_face_quant_postprocess_edgetpu.tflite
#    labels: /opt/ambianic-edge/ai_models/coco_labels.txt
#    top_k: 2

## config.ai_models
ambianic::config.ai_models()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local cpath=${1:-${CONFIG_PATH}}
  local ai_models=$(jq '.ai_models' ${cpath})
  local result
  local models='['

 if [ "${ai_models:-null}" != 'null' ]; then
    local nmodel=$(echo "${ai_models}" | jq '.|length')

    i=0; j=0; while ${i} -lt ${nmodel}; do
      local model=$(echo "${ai_models}" | jq -c '.['${i}']')

      if [ "${model:-null}" != 'null' ]; then
        local type=$(echo "${model}" | jq -r '.type')
        local src='null'

        case ${type:-null} in
          video)
            src=$(ambianic::config.ai_models.video "${model}")
            if [ "${src:-null}" = 'null' ]; then
              bashio::log.warn "FAILED to configure ai_model ${i}: ${video}"
            else
              bashio::log.debug "Configured ai_model ${i}: ${src}"
              if [ ${j} -gt 0 ]; then srcs="${srcs},"; fi
                srcs="${srcs}${src}"
              fi
              j=$((j+1))
            fi
            ;;
          *)
            bashio::log.warn "Invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
    srcs="${srcs}]"
    bashio::log.debug "AI Models: ${srcs}"
    result=${srcs}
  else
    bashio::log.notice "No ai_models defined; configuration: ${cpath}"
  fi
  echo ${result:-null}
}

## config.pipelines
ambianic::config.pipelines()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local cpath=${1:-${CONFIG_PATH}}
  local result
  echo ${result:-null}
}


## config
ambianic::config()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local cpath=${1:-${CONFIG_PATH}}
  local workspace=$(jq -r '.workspace' ${cpath})
  local result
  
  if [ "${workspace:-null}" != 'null' ]; then
    bashio::log.debug "Ambianic workspace: ${workspace}"

    local config='{"workspace":"'${workspace}'"}'
    local ok

    mkdir -p "${workspace}"

    ok=$(ambianic::config.ai_models "${cpath}")
    if [ "${ok:-null}" != 'null' ]; then
      bashio::log.debug "AI Models configured:" $(echo "${ok}" | jq -c '.') 
      # record in configuration
      config=$(echo "${config:-null}" | jq '.ai_models='"${ok}")
      ok=$(ambianic::config.sources "${cpath}")
      if [ "${ok:-null}"  != 'null' ]; then
        bashio::log.debug "Sources configured:" $(echo "${ok}" | jq -c '.') 
        # record in configuration
        config=$(echo "${config:-null}" | jq '.sources='"${ok}")
        ok=$(ambianic::config.pipelines "${cpath}")
        if [ "${ok:-null}" != 'null' ]; then
          bashio::log.debug "Pipelines configured:" $(echo "${ok}" | jq -c '.') 
          # record in configuration
          config=$(echo "${config:-null}" | jq '.pipelines='"${ok}")

          # SUCCESS
          result="${config}"
        else
          bashio::log.error "Failed to configure pipelines; config: ${cpath}"
        fi
      else
        bashio::log.error "Failed to configure sources; config: ${cpath}"
      fi
    else
      bashio::log.error "Failed to configure ai_models; config: ${cpath}"
    fi
  else
    bashio::log.error "Ambianic workspace is not defined"
  fi
  echo "${result:-null}"
}


###
## START
###

## start.proxy
ambianic::start.proxy()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local result
  local ok
  local proxy=${1:-peerjs.ext.http-proxy}
  local t=$(mktemp)

  python3 -m  ${proxy} &> ${t} &
  ok=$!; if [ ${ok:-0} -gt 0 ]; then
    bashio::log.debug "PeerJS proxy started; pid: ${ok}"
    result='{"proxy":"'${proxy}'","pid":'${ok}',"out":"'${t}'"}'
  else 
    bashio::log.error "PeerJS proxy failed to start" $(cat ${t})
    rm -f ${t}
  fi
  echo ${result:-null}
}

## start.ambianic
ambianic::start.ambianic()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local result
  local ok
  local ambianic="${1:-ambianic}"
  local t=$(mktemp)

  if [ "${config:-null}" != 'null' ]; then
    echo "${config}" > ${AMBIANIC_WORKSPACE}/config.yaml

    python3 -m ${ambianic} &> ${t} &
    ok=$!; if [ ${ok:-0} -gt 0 ]; then
      bashio::log.debug "Ambianic started; pid: ${ok}"
      result='{"ambianic":"'${ambianic}'","pid":'${ok}',"out":"'${t}'"}'
    else
      bashio::log.error "Ambianic failed to start"
      rm -f ${t}
    fi
  else
    bashio::log.error "No configuration provided"
  fi

  echo ${result:-null}
}

## start
ambianic::start()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local result
  local cpath="${1:-${CONFIG_PATH}}"
  local config=$(ambianic::config ${cpath})

  if [ "${config:-null}" != 'null' ]; then
    # start proxy
    ok=$(ambianic::start.proxy)
    if [ "${ok:-null}" != 'null' ]; then
      bashio::log.debug "Proxy started:" $(echo "${ok}" | jq -c '.') 
      config=$(echo "${config:-null}" | jq '.proxy='"${ok}")

      # start ambianic
      ok=$(ambianic::start.ambianic "${config}")
      if [ "${ok:-null}" != 'null' ]; then
        bashio::log.debug "Ambianic started:" $(echo "${ok}" | jq -c '.') 
        config=$(echo "${config:-null}" | jq '.ambianic='"${ok}")
        result=${config}
      else 
        bashio::log.error "Ambianic failed to start"
      fi
    else 
      bashio::log.error "Proxy failed to start"
    fi
  else 
    bashio::log.error "Configuration failed"
  fi
  echo ${result:-null}
}

###
## PRE-FLIGHT
###

if [ ! -d "${AMBIANIC_PATH}" ]; then
  bashio::log.error "Ambianic not installed; path: ${AMBIANIC_PATH}"
  exit 1
fi

###
## MAIN
###

bashio::log.notice "STARTING AMBIANIC: $(CONFIG_PATH}"

ambianic::start ${CONFIG_PATH}
