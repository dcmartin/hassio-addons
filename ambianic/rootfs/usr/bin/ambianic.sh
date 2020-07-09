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
## SOURCES
###

##
## update (write YAML)
##

# EXAMPLE:
#^sources:
#^  front_door_cam_feed: &src_recorded_cam_feed
#^    uri: rtsp://admin:password@192.168.1.99/media/video1
#^    type: video
#^    live: true
#^  entry_area_cam_feed: &src_recorded_cam_feed
#^    uri: rtsp://admin:mike@192.168.1.99/media/video1
#^    type: video
#^    live: true

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

ambianic::update.sources.audio()
{
  bashio::log.warn "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.sources()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local sources=$(echo "${config}" | jq '.sources')

  if [ "${sources:-null}" != 'null' ]; then
    local nsource=$(echo "${sources}" | jq '.|length')

    # START OUTPUT
    echo 'sources:'

    i=0; while ${i} -lt ${nsource}; do
      local source=$(echo "${sources}" | jq -c '.['${i}']')

      if [ "${source:-null}" != 'null' ]; then
        local type=$(echo "${source}" | jq -r '.type')
        local src='null'

        case ${type:-null} in
          video)
            ambianic::update.sources.video "${source}"
            ;;
          audio)
            ambianic::update.sources.audio "${source}"
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

##
## configure (read JSON)
##

# EXAMPLE:
#[
#  {
#    "name": "camera1",
#    "uri": "rtsp://username:password@192.168.1.221/live",
#    "type": "video",
#    "live": true
#  },
#  {
#    "name": "camera2",
#    "uri": "rtsp://username:password@192.168.1.222/live",
#    "type": "video",
#    "live": true
#  }
#]

ambianc::config.sources.audio()
{
  bashio::log.warn "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianc::config.sources.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local source="${*}"
  local result
  local name=$(echo "${source:-null}" | jq -r '.name')

  if [ "${name:-null}" != 'null' ]; then
    bashio::log.debug "Name: ${name}"
    local uri=$(echo "${source:-null}" | jq -r '.uri')
    if [ "${uri:-null}" != 'null' ]; then
      bashio::log.debug "URI: ${uri}"
      local type=$(echo "${source:-null}" | jq -r '.type')
      if [ "${type:-null}" != 'null' ]; then
        bashio::log.debug "Type: ${type}"
        local live=$(echo "${source:-null}" | jq '.live')
        if [ "${live:-null}" != 'null' ]; then
          bashio::log.debug "Live: ${live}"

          result='{"name":"'${name}'","uri":"'${uri}'","type":"'${type}'","live":'${live}'}'

          bashio::log.info "${FUNCNAME[0]}: source: ${result}"
        else
          bashio::log.error "Live unspecified: ${source}"
        fi
      else
        bashio::log.error  "Type unspecified: ${source}"
      fi
    else
      bashio::log.error  "URI unspecified: ${source}"
    fi
  else
    bashio::log.error  "Name unspecified: ${source}"
  fi
  echo ${result:-null}
}

ambianic::config.sources()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"
  
  local cpath=${1:-${CONFIG_PATH}}
  local sources=$(jq '.sources' ${cpath})
  local result
  local srcs='['

  if [ "${sources:-null}" != 'null' ]; then
    local nsource=$(echo "${sources}" | jq '.|length')

    i=0; j=0; while ${i} -lt ${nsource}; do
      local source=$(echo "${sources}" | jq -c '.['${i}']')

      if [ "${source:-null}" != 'null' ]; then
        local type=$(echo "${source}" | jq -r '.type')
        local src

        case ${type:-null} in
          video)
            src=$(ambianic::config.sources.video "${source}")
            ;;
          audio)
            src=$(ambianic::config.sources.audio "${source}")
            ;;
          *)
            bashio::log.warn "Invalid source type: ${type}"
            ;;
        esac
        if [ "${src:-null}" = 'null' ]; then
          bashio::log.warn "FAILED to source ${type} ${i}: ${source}"
        else
          bashio::log.debug "Sourced ${type} ${i}: ${src}"
          if [ ${j} -gt 0 ]; then srcs="${srcs},"; fi
            srcs="${srcs}${src}"
          fi
          j=$((j+1))
        fi
      fi
      i=$((i+1))
    done
    srcs="${srcs}]"
    bashio::log.debug "Sources: ${srcs}"
    result=${srcs}
  else
    bashio::log.notice "No sources defined; configuration: ${cpath}"
  fi
  echo ${result:-null}
}

###
## AI_MODELS
###

##
## update (write YAML)
##

# EXAMPLE:
#^ai_models:
#^  image_detection: &tfm_image_detection
#^    labels: /opt/ambianic-edge/ai_models/coco_labels.txt
#^    model:
#^      tflite: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_coco_quant_postprocess.tflite
#^      edgetpu: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_coco_quant_postprocess_edgetpu.tflite
#^  face_detection: &tfm_face_detection
#^    labels: /opt/ambianic-edge/ai_models/coco_labels.txt
#^    top_k: 2
#^    model:
#^      tflite: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_face_quant_postprocess.tflite
#^      edgetpu: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_face_quant_postprocess_edgetpu.tflite

ambianic::update.ai_models.audio()
{
  bashio::log.warn "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.ai_models.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local model="${*}"
  local name=$(echo "${model:-null}" | jq -r '.name')
  local labels=$(echo "${model:-null}" | jq -r '.labels')
  local entity=$(echo "${model:-null}" | jq -r '.entity')
  local top_k=$(echo "${model:-null}" | jq -r '.top_k')
  local tflite=$(echo "${model:-null}" | jq -r '.tflite')
  local edgetpu=$(echo "${model:-null}" | jq -r '.edgetpu')

  case ${entity} in:
    object)
      echo '  image_detection: &'${name}
      echo '    labels: '${labels} | envsubst
      echo '    top_k: '${top_k}
      echo '    model:'
      echo '      tflite: '${tflite} | envsubst
      echo '      edgetpu: '${edgetpu} | envsubst
      ;;
    face)
      echo '  face_detection: &'${name}
      echo '    labels: '${labels} | envsubst
      echo '    top_k: '${top_k}
      echo '    model:'
      echo '      tflite: '${tflite} | envsubst
      echo '      edgetpu: '${edgetpu} | envsubst
      ;;
    *)
      bashio::log.error "Invalid entity: ${entity}"
      ;;
  esac
}

ambianic::update.ai_models()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local ai_models=$(echo "${config}" | jq '.ai_models')

  if [ "${ai_models:-null}" != 'null' ]; then
    local nai_model=$(echo "${ai_models}" | jq '.|length')

    # START OUTPUT
    echo 'ai_models:'

    i=0; while ${i} -lt ${nai_model}; do
      local ai_model=$(echo "${ai_models}" | jq -c '.['${i}']')

      if [ "${ai_model:-null}" != 'null' ]; then
        local type=$(echo "${ai_model}" | jq -r '.type')
        local src='null'

        case ${type:-null} in
          video)
            ambianic::update.ai_models.video "${ai_model}"
            ;;
          audio)
            ambianic::update.ai_models.audio "${ai_model}"
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

##
## configure (read JSON)
##

#EXAMPLE:
#[
#  {
#    "name": "entity_detection",
#    "type": "video",
#    "top_k": 10,
#    "labels": "${AMBIABIC_PATH}/ai_models/coco_labels.txt",
#    "tflite": "${AMBIABIC_PATH}/ai_models/mobilenet_ssd_v2_coco_quant_postprocess.tflite",
#    "edgetpu": "${AMBIANIC_PATH}/ai_models/mobilenet_ssd_v2_coco_quant_postprocess_edgetpu.tflite"
#  },
#  {
#    "name": "face_detection",
#    "type": "video",
#    "top_k": 2,
#    "labels": "${AMBIANIC_PATH}/ai_models/coco_labels.txt",
#    "tflite": "${AMBIANIC_PATH}/ai_models/mobilenet_ssd_v2_face_quant_postprocess.tflite",
#    "edgetpu": "${AMBIANIC_PATH}/ai_models/mobilenet_ssd_v2_face_quant_postprocess_edgetpu.tflite"
#  }
#]

ambianc::config.ai_models.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local model="${*}"
  local result
  local name=$(echo "${model:-null}" | jq -r '.name')

  if [ "${name:-null}" != 'null' ]; then
    bashio::log.debug "Name: ${name}"
    local labels=$(echo "${model:-null}" | jq -r '.labels')
    if [ "${labels:-null}" != 'null' ]; then
      bashio::log.debug "Labels: ${labels}"
      local top_k=$(echo "${model:-null}" | jq -r '.top_k')
      if [ "${top_k:-null}" != 'null' ]; then
        bashio::log.debug "TopK: ${top_k}"
        local tflite=$(echo "${model:-null}" | jq -r '.tflite')
        if [ "${tflite:-null}" != 'null' ]; then
          bashio::log.debug "TFlite: ${tflite}"

          # edgetpu is optional
          local edgetpu=$(echo "${model:-null}" | jq -r '.edgetpu')
          bashio::log.debug "EdgeTPU: ${edgetpu}"

          result='{"name":"'${name}'","labels":"'${labels}'","top_k":"'${top_k}'","tflite":'${tflite}',"edgetpu":"'${edgetpu}'"}'

          bashio::log.info "${FUNCNAME[0]}: ai_model: ${result}"
        else
          bashio::log.error "TFlite unspecified: ${model}"
        fi
      else
        bashio::log.error  "TopK unspecified: ${model}"
      fi
    else
      bashio::log.error  "Labels unspecified: ${model}"
    fi
  else
    bashio::log.error  "Name unspecified: ${model}"
  fi
  echo ${result:-null}
}

ambianic::config.ai_models.audio()
{
  bashio::log.warn "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

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
        local model

        case ${type:-null} in
          video)
            model=$(ambianic::config.ai_models.video "${model}")
            ;;
          audio)
            model=$(ambianic::config.ai_models.audio "${model}")
            ;;
          *)
            bashio::log.warn "Invalid ai_model type: ${type}"
            ;;
        esac
        if [ "${model:-null}" = 'null' ]; then
          bashio::log.warn "FAILED to configure ai_model ${i}: ${video}"
        else
          bashio::log.debug "Configured ai_model ${i}: ${model}"
          if [ ${j} -gt 0 ]; then models="${models},"; fi
            models="${models}${model}"
          fi
          j=$((j+1))
        fi
      fi
      i=$((i+1))
    done
    models="${models}]"
    bashio::log.debug "AI Models: ${models}"
    result=${models}
  else
    bashio::log.notice "No ai_models defined; configuration: ${cpath}"
  fi
  echo ${result:-null}
}

###
## PIPELINES
###

##
## update
##

# EXAMPLE:
#^pipelines:
#^  # sequence of piped operations for use in daytime front door watch
#^  front_door_watch:
#^    - source: *src_recorded_cam_feed
#^    - detect_objects: # run ai inference on the input data
#^       <<: *tfm_image_detection
#^       confidence_threshold: 0.6
#^    - save_detections: # save samples from the inference results
#^       positive_interval: 2 # how often (in seconds) to save samples with ANY results above the confidence threshold
#^       idle_interval: 6000 # how often (in seconds) to save samples with NO results above the confidence threshold
#^    - detect_faces: # run ai inference on the samples from the previous element output
#^       <<: *tfm_face_detection
#^       confidence_threshold: 0.6
#^    - save_detections: # save samples from the inference results
#^       positive_interval: 2
#^       idle_interval: 600

ambianic::update.pipelines.video.detect()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local act="${*}"
  local ai_model=$(echo "${act:-null}" | jq -r '.ai_model')
  local entity=$(echo "${act:-null}" | jq -r '.entity')
  local confidence=$(echo "${act:-null}" | jq -r '.confidence')

  case ${entity} in:
    object)
      echo '    - detect_objects:'
      echo '      <<: *'${ai_model}
      echo '      confidence_threshold: '${confidence}
      ;;
    face)
      echo '    - detect_faces:'
      echo '      <<: *'${ai_model}
      echo '      confidence_threshold: '${confidence}
      ;;
    *)
      bashio::log.warn "Invalid entity: ${entity}"
      ;;
  esac
}

ambianic::update.pipelines.video.save()
{
  bashio::log.warn "${FUNCNAME[0]}" "${*}"

  local act="${*}"
  local interval=$(echo "${act:-null}" | jq -r '.interval')
  local idle=$(echo "${act:-null}" | jq -r '.idle')

  echo '   - save_detections:'
  echo '     positive_interval: '${interval}
  echo '     idle_interval: '${idle}
}

ambianic::update.pipelines.video.send()
{
  bashio::log.warn "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.pipelines.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local pipeline="${*}"
  local name=$(echo "${pipeline:-null}" | jq -r '.name')
  local source=$(echo "${pipeline:-null}" | jq -r '.source')
  local steps=$(echo "${pipeline:-null}" | jq -r '.steps')

  if [ ! -z "${name:-}" ] && [ ! -z "${source:-}" ] && [ "${steps:-null}" != 'null' ]; then
    local nstep=$(echo "${steps}" | jq '.|length')

    bashio::log.debug "Pipeline: ${name}; source: ${source}; steps: ${nstep}"

    # start output
    echo '  '${name}':'
    echo '    - source: *'${source}

    i=0; while ${i} -lt ${nstep}; do
      local step=$(echo "${steps}" | jq -c '.['${i}']')

      if [ "${step:-null}" != 'null' ]; then
        local actions=$(echo "${step}" | jq -r '.|to_entries[].key')

        j=0; for a in "${actions:-null}"; do
          local act=$(echo "${actions}" | jq '.|to_entries['${j}'].value')

          case ${a} in
            detect)
              ambianic::update.pipelines.video.detect "${act}"
              ;;
            save)
              ambianic::update.pipelines.video.save "${act}"
              ;;
            send)
              ambianic::update.pipelines.video.send "${act}"
              ;;
            *)
              bashio::log.warn "Invalid action: ${a}"
              ;;
          esac
        j=$((j+1))
        done
      fi
      i=$((i+1))
    done
  else
    bashio::log.error "Invalid pipeline: ${pipeline}"
  fi
}

ambianic::update.pipelines()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local pipelines=$(echo "${config}" | jq '.pipelines')

  if [ "${pipelines:-null}" != 'null' ]; then
    local npipeline=$(echo "${pipelines}" | jq '.|length')

    # START OUTPUT
    echo 'pipelines:'

    i=0; while ${i} -lt ${npipeline}; do
      local pipeline=$(echo "${pipelines}" | jq -c '.['${i}']')

      if [ "${pipeline:-null}" != 'null' ]; then
        local type=$(echo "${pipeline}" | jq -r '.type')

        case ${type:-null} in
          image)
            ambianic::update.pipelines.image "${pipeline}"
            ;;
          face)
            ambianic::update.pipelines.face "${pipeline}"
            ;;
          audio)
            ambianic::update.pipelines.audio "${pipeline}"
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

##
## configure
##

# EXAMPLE:
#[
#  {
#    "name": "camera1_entity_face",
#    "source": "camera1",
#    "type": "video",
#    "steps": [
#      { 
#        "detect": { "entity": "object", "ai_model": "entity_detection", "confidence": 0.6 },
#        "save": { "interval": 2, "idle": 6000 }
#      },
#      {
#        "detect": { "entity": "face", "ai_model": "face_detection", "confidence": 0.6 },
#        "save": { "interval": 2, "idle": 600 }
#      }
#    ]
#  },
#  {
#    "name": "camera2_entity_face",
#    "source": "camera2",
#    "type": "video",
#    "steps": [
#      {
#        "detect": { "entity": "object", "ai_model": "entity_detection", "confidence": 0.6 },
#        "save": { "interval": 2, "idle": 600 } },
#      {
#        "detect": { "entity": "face", "ai_model": "face_detection", "confidence": 0.6 },
#        "save": { "interval": 2, "idle": 600 }
#      }
#    ]
#  }
#]

ambianc::config.pipelines.audio()
{
  bashio::log.warn "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianc::config.pipelines.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local pipeline="${*}"
  local result
  local name=$(echo "${pipeline:-null}" | jq -r '.name')

  if [ "${name:-null}" != 'null' ]; then
    bashio::log.debug "Name: ${name}"
    local source=$(echo "${pipeline:-null}" | jq -r '.source')
    if [ "${source:-null}" != 'null' ]; then
      bashio::log.debug "URI: ${source}"
      local type=$(echo "${pipeline:-null}" | jq -r '.type')
      if [ "${type:-null}" != 'null' ]; then
        bashio::log.debug "Type: ${type}"
        local steps=$(echo "${pipeline:-null}" | jq '.steps')
        if [ $(echo "${steps:-null}" | jq '.|length') -gt 0 ]; then
          bashio::log.debug "Steps: ${steps}"

          result='{"name":"'${name}'","source":"'${source}'","type":"'${type}'","steps":'"${steps}"'}'

          bashio::log.info "${FUNCNAME[0]}: pipeline: ${result}"
        else
          bashio::log.error "Steps unspecified: ${pipeline}"
        fi
      else
        bashio::log.error  "Type unspecified: ${pipeline}"
      fi
    else
      bashio::log.error  "Source unspecified: ${pipeline}"
    fi
  else
    bashio::log.error  "Name unspecified: ${pipeline}"
  fi
  echo ${result:-null}
}

ambianic::config.pipelines()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local cpath=${1:-${CONFIG_PATH}}
  local pipelines=$(jq '.pipelines' ${cpath})
  local result
  local ppls='['

 if [ "${pipelines:-null}" != 'null' ]; then
    local nppl=$(echo "${pipelines}" | jq '.|length')

    i=0; j=0; while ${i} -lt ${nppl}; do
      local ppl=$(echo "${pipelines}" | jq -c '.['${i}']')

      if [ "${ppl:-null}" != 'null' ]; then
        local type=$(echo "${ppl}" | jq -r '.type')
        local ppl

        case ${type:-null} in
          video)
            ppl=$(ambianic::config.pipelines.video "${ppl}")
            ;;
          audio)
            ppl=$(ambianic::config.pipelines.audio "${ppl}")
            ;;
          *)
            bashio::log.warn "Invalid pipeline type: ${type}"
            ;;
        esac
        if [ "${ppl:-null}" = 'null' ]; then
          bashio::log.warn "FAILED to configure pipeline ${i}: ${video}"
        else
          bashio::log.debug "Configured pipeline ${i}: ${ppl}"
          if [ ${j} -gt 0 ]; then ppls="${ppls},"; fi
            ppls="${ppls}${ppl}"
          fi
          j=$((j+1))
        fi
      fi
      i=$((i+1))
    done
    ppls="${ppls}]"
    bashio::log.debug "Pipelines: ${ppls}"
    result=${ppls}
  else
    bashio::log.notice "No pipelines defined; configuration: ${cpath}"
  fi
  echo ${result:-null}
}

###
## CONFIGURATION (read JSON)
###

ambianic::config()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local cpath=${1:-${CONFIG_PATH}}
  local workspace=$(jq -r '.workspace' ${cpath})
  local result
  
  if [ "${workspace:-null}" != 'null' ]; then
    mkdir -p "${workspace}"
    if [ -d "${workspace}" ]; then
      local config='{"workspace":"'${workspace}'"}'
      local ok

      # broadcast
      export AMBIANIC_WORKSPACE=${workspace}
      bashio::log.info "Workspace: ${workspace}"

      # configure ai_models
      ok=$(ambianic::config.ai_models "${cpath}")
      if [ "${ok:-null}" != 'null' ]; then
        bashio::log.debug "AI Models configured:" $(echo "${ok}" | jq -c '.') 
        # record in configuration
        config=$(echo "${config:-null}" | jq '.ai_models='"${ok}")

        # configure sources
        ok=$(ambianic::config.sources "${cpath}")
        if [ "${ok:-null}"  != 'null' ]; then
          bashio::log.debug "Sources configured:" $(echo "${ok}" | jq -c '.') 
          # record in configuration
          config=$(echo "${config:-null}" | jq '.sources='"${ok}")

          # configure pipelines
          ok=$(ambianic::config.pipelines "${cpath}")
          if [ "${ok:-null}" != 'null' ]; then
            bashio::log.debug "Pipelines configured:" $(echo "${ok}" | jq -c '.') 
            # record in configuration
            config=$(echo "${config:-null}" | jq '.pipelines='"${ok}")
  
            # success
            result="${config}"
            bashio::log.info "Ambianic configured:" $(echo "${result}" | jq -c '.')
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
      bashio::log.error "Failed to create workspace directory: ${workspace}"
    fi
  else
    bashio::log.error "Ambianic workspace is not defined"
  fi
  echo "${result:-null}"
}

###
## UPDATE (write YAML)
###

ambianic::update()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"

  ambianic::update.ai_models >> ${AMBIANIC_CONFIG}
  ambianic::update.sources >> ${AMBIANIC_CONFIG}
  ambianic::update.pipelines >> ${AMBIANIC_CONFIG}
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

  local config="${config:-null}"
  local result
  local t=$(mktemp)

  if [ "${config:-null}" != 'null' ]; then
    local ok
    local ambianic=${AMBIANIC_WORKSPACE}/config.yaml

    # update YAML
    ambianic::update "${config}" > ${ambianic}

    # start python3
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

## start all
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
        bashio::log.notice "Ambianic started:" $(echo "${ok}" | jq -c '.') 

        config=$(echo "${config:-null}" | jq '.ambianic='"${ok}")
        result=${config}
      else 
        bashio::log.error "Ambianic failed to start"
      fi
    else 
      bashio::log.error "Proxy failed to start"
    fi
  else 
    bashio::log.error "Configuration failed; ${cpath}:" $(jq -c '.' ${cpath})
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
