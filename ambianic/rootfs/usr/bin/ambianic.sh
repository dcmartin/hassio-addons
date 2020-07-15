#!/usr/bin/with-contenv bashio

###
## FUNCTIONS
###

## configuration
config()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]} ${*}"

  local VALUE
  local JSON='{"ipaddr":"'$(hostname -i)'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)

  ## time zone
  VALUE=$(bashio::config 'timezone')
  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
    VALUE="GMT"
    bashio::log.warning "timezone unspecified; defaulting to ${VALUE}"
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
  VALUE=$(bashio::config 'unit_system')
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
  bashio::log.info "Set unit_system to ${VALUE}"
  JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'
  # latitude
  VALUE=$(bashio::config 'latitude')
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
  bashio::log.info "Set latitude to ${VALUE}"
  JSON="${JSON}"',"latitude":'"${VALUE}"
  # longitude
  VALUE=$(bashio::config 'longitude')
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
  bashio::log.info "Set longitude to ${VALUE}"
  JSON="${JSON}"',"longitude":'"${VALUE}"
  # elevation
  VALUE=$(bashio::config 'elevation')
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
  bashio::log.info "Set elevation to ${VALUE}"
  JSON="${JSON}"',"elevation":'"${VALUE}"
  
  ## MQTT
  # host
  VALUE=$(bashio::config 'mqtt.host')
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
  bashio::log.info "Using MQTT at ${VALUE}"
  MQTT='{"host":"'"${VALUE}"'"'
  # username
  VALUE=$(bashio::config 'mqtt.username')
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  bashio::log.info "Using MQTT username: ${VALUE}"
  MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
  # password
  VALUE=$(bashio::config 'mqtt.password')
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  bashio::log.info "Using MQTT password: ${VALUE}"
  MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
  # port
  VALUE=$(bashio::config 'mqtt.port')
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

ambianic::config.sources.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::config.sources.video()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

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
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"
  
  local sources=$(jq '.sources' ${__BASHIO_DEFAULT_ADDON_CONFIG})
  local result
  local srcs='['

  if [ "${sources:-null}" != 'null' ]; then
    local nsource=$(echo "${sources}" | jq '.|length')
    local i=0
    local j=0

    while [ ${i} -lt ${nsource} ]; do
      local source=$(echo "${sources}" | jq -c '.['${i}']')
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
          bashio::log.warning "Invalid source type: ${type}"
          ;;
      esac
      if [ "${src:-null}" = 'null' ]; then
        bashio::log.warning "FAILED to source ${type} ${i}: ${source}"
      else
        bashio::log.debug "Sourced ${type} ${i}: ${src}"
        if [ ${j} -gt 0 ]; then srcs="${srcs},"; fi
        srcs="${srcs}${src}"
        j=$((j+1))
      fi
      i=$((i+1))
    done
    srcs="${srcs}]"
    bashio::log.debug "Sources: ${srcs}"
    result=${srcs}
  else
    bashio::log.notice "No sources defined"
  fi
  echo ${result:-null}
}

###
## UPDATE (write YAML)
###

##
## SOURCES
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
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

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
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.sources()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}"

  local sources="${*}"

  if [ "${sources:-null}" != 'null' ]; then
    local nsource=$(echo "${sources}" | jq '.|length')
    local i=0

    # START OUTPUT
    echo 'sources:'

    while [ ${i} -lt ${nsource} ]; do
      local source=$(echo "${sources}" | jq -c '.['${i}']')


      if [ "${source:-null}" != 'null' ]; then
        local type=$(echo "${source}" | jq -r '.type')

        bashio::log.debug "Source: ${source}"
        case ${type:-null} in
          video)
            ambianic::update.sources.video "${source}"
            ;;
          audio)
            ambianic::update.sources.audio "${source}"
            ;;
          *)
            bashio::log.warning "Invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
  else
    bashio::log.error "No sources defined; configuration:" $(echo "${config:-null}" | jq -c '.')
  fi
}

##
## AI_MODELS
##

# EXAMPLE:
#^ai_models:
#^  image_detection: &tfm_image_detection
#^    labels: /opt/ambianic-edge/ai_models/coco_labels.txt
#^    model:
#^      tflite: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_coco_quant_postprocess.tflite
#^  face_detection: &tfm_face_detection
#^    labels: /opt/ambianic-edge/ai_models/coco_labels.txt
#^    top_k: 2
#^    model:
#^      tflite: /opt/ambianic-edge/ai_models/mobilenet_ssd_v2_face_quant_postprocess.tflite

ambianic::update.ai_models.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.ai_models.video()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}"

  local model="${*}"
  local name=$(echo "${model:-null}" | jq -r '.name')
  local labels=$(echo "${model:-null}" | jq -r '.labels')
  local entity=$(echo "${model:-null}" | jq -r '.entity')
  local top_k=$(echo "${model:-null}" | jq -r '.top_k')
  local tflite=$(echo "${model:-null}" | jq -r '.tflite')

  case ${entity} in
    object)
      echo '  image_detection: &'${name}
      echo '    labels: '${labels} | envsubst
      echo '    top_k: '${top_k}
      echo '    model:'
      echo '      tflite: '${tflite} | envsubst
      ;;
    face)
      echo '  face_detection: &'${name}
      echo '    labels: '${labels} | envsubst
      echo '    top_k: '${top_k}
      echo '    model:'
      echo '      tflite: '${tflite} | envsubst
      ;;
    *)
      bashio::log.error "Invalid entity: ${entity}"
      ;;
  esac
}

ambianic::update.ai_models()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}"

  local ai_models="${*}"

  if [ "${ai_models:-null}" != 'null' ]; then
    local nai_model=$(echo "${ai_models}" | jq '.|length')
    local i=0

    # START OUTPUT
    echo 'ai_models:'

    while [ ${i} -lt ${nai_model} ]; do
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
            bashio::log.warning "Invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
  else
    bashio::log.error "No ai_models defined; configuration:" $(echo "${config:-null}" | jq -c '.')
  fi
}

##
## ALL
##

ambianic::update()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}"

  local config="${*}"
  local ambianic=$(echo "${config}" | jq -r '.workspace')/config.yaml

  rm -f ${ambianic}

  ambianic::update.ai_models $(echo "${config}" | jq '.ai_models') >> ${ambianic}
  ambianic::update.sources $(echo "${config}" | jq '.sources') >> ${ambianic}
  ambianic::update.pipelines $(echo "${config}" | jq '.pipelines') >> ${ambianic}

  echo "${ambianic}"
}

###
## configure (read JSON)
###

##
## AI MODELS
##

#EXAMPLE:
#[
#  {
#    "name": "entity_detection",
#    "type": "video",
#    "top_k": 10,
#    "labels": "${AMBIABIC_PATH}/ai_models/coco_labels.txt",
#    "tflite": "${AMBIABIC_PATH}/ai_models/mobilenet_ssd_v2_coco_quant_postprocess.tflite"
#  },
#  {
#    "name": "face_detection",
#    "type": "video",
#    "top_k": 2,
#    "labels": "${AMBIANIC_EDGE}/ai_models/coco_labels.txt",
#    "tflite": "${AMBIANIC_EDGE}/ai_models/mobilenet_ssd_v2_face_quant_postprocess.tflite"
#  }
#]

ambianic::config.ai_models.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::config.ai_models.video()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

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

          result='{"name":"'${name}'","labels":"'${labels}'","top_k":"'${top_k}'","tflite":"'${tflite}'"}'

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

ambianic::config.ai_models()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

  local ai_models=$(jq '.ai_models' ${__BASHIO_DEFAULT_ADDON_CONFIG})
  local result
  local models='['

  bashio::log.debug "AI MODELS: ${ai_models}"

  if [ "${ai_models:-null}" != 'null' ]; then
    local nmodel=$(echo "${ai_models}" | jq '.|length')
    local i=0
    local j=0

    while [ ${i:-0} -lt ${nmodel:-0} ]; do
      local model=$(echo "${ai_models}" | jq -c '.['${i}']')
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
          bashio::log.warning "Invalid ai_model type: ${type}"
          ;;
      esac
      if [ "${model:-null}" = 'null' ]; then
        bashio::log.warning "FAILED to configure ai_model ${i}: ${model}"
      else
        bashio::log.debug "Configured ai_model ${i}: ${model}"
        if [ ${j} -gt 0 ]; then models="${models},"; fi
        models="${models}${model}"
        j=$((j+1))
      fi
      i=$((i+1))
    done
    models="${models}]"
    bashio::log.debug "AI Models: ${models}"
    result=${models}
  else
    bashio::log.notice "No ai_models defined"
  fi
  echo ${result:-null}
}

##
## PIPELINES
##

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
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

  local act="${*}"
  local ai_model=$(echo "${act:-null}" | jq -r '.ai_model')
  local entity=$(echo "${act:-null}" | jq -r '.entity')
  local confidence=$(echo "${act:-null}" | jq -r '.confidence')

  case ${entity} in
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
      bashio::log.warning "Invalid entity: ${entity}"
      ;;
  esac
}

ambianic::update.pipelines.video.save()
{
  bashio::log.warning "${FUNCNAME[0]}" "${*}"

  local act="${*}"
  local interval=$(echo "${act:-null}" | jq -r '.interval')
  local idle=$(echo "${act:-null}" | jq -r '.idle')

  echo '   - save_detections:'
  echo '     positive_interval: '${interval}
  echo '     idle_interval: '${idle}
}

ambianic::update.pipelines.video.send()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.pipelines.video()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

  local pipeline="${*}"
  local name=$(echo "${pipeline:-null}" | jq -r '.name')
  local source=$(echo "${pipeline:-null}" | jq -r '.source')
  local actions=$(echo "${pipeline:-null}" | jq '.actions')
  local naction=$(echo "${actions:-null}" | jq '.|length')

  if [ ! -z "${name:-}" ] && [ ! -z "${source:-}" ] && [ "${actions:-null}" != 'null' ]; then
    bashio::log.debug "Pipeline: ${name}; source: ${source}; actions: ${naction}"
    local i=0

    # start output
    echo '  '${name}':'
    echo '    - source: *'${source}

    while [ ${i} -lt ${naction} ]; do
      local action=$(echo "${actions}" | jq -c '.['${i}']')

      if [ "${action:-null}" != 'null' ]; then
        local act=$(echo "${action}" | jq '.act')

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
              bashio::log.warning "Invalid act: ${a}"
              ;;
          esac
      else
        bashio::log.error "Invalid action: ${action}"
      fi
      i=$((i+1))
    done
  else
    bashio::log.error "Invalid pipeline: ${pipeline}"
  fi
}

ambianic::update.pipelines()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

  local pipelines="${*}"

  if [ "${pipelines:-null}" != 'null' ]; then
    local npipeline=$(echo "${pipelines}" | jq '.|length')
    local i=0

    # START OUTPUT
    echo 'pipelines:'

    while [ ${i} -lt ${npipeline} ]; do
      local pipeline=$(echo "${pipelines}" | jq -c '.['${i}']')

      if [ "${pipeline:-null}" != 'null' ]; then
        local type=$(echo "${pipeline}" | jq -r '.type')

        case ${type:-null} in
          image)
            ambianic::update.pipelines.video "${pipeline}"
            ;;
          audio)
            ambianic::update.pipelines.audio "${pipeline}"
            ;;
          *)
            bashio::log.warning "Invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
  else
    bashio::log.notice "No pipelines defined; configuration:" $(echo "${config:-null}" | jq -c '.')
  fi
}

##
## configure
##

# EXAMPLE:
#    "pipelines": [
#      {
#        "name": "camera1-pipeline",
#        "source": "camera1",
#        "type": "video",
#        "action": "detect_object_action"
#      },
#      {
#        "name": "camera1-pipeline",
#        "source": "detect_object_action",
#        "type": "video",
#        "action": "save_object_action"
#      },
#      {
#        "name": "camera2-pipeline",
#        "source": "camera2",
#        "type": "video",
#        "action": "detect_face_action"
#      },
#      {
#        "name": "camera2-pipeline",
#        "source": "detect_face_action",
#        "type": "video",
#        "action": "save_face_action"
#      }
#    ]
#
#    "actions": [
#      {
#        "name": "detect_object_action",
#        "act": "detect",
#        "type": "video",
#        "entity": "object",
#        "ai_model": "entity_detection",
#        "confidence": 0.6
#      },
#      {
#        "name": "save_object_action",
#        "act": "save",
#        "type": "video",
#        "interval": 2,
#        "idle": 600
#      },
#      {
#        "name": "detect_face_action",
#        "act": "detect",
#        "type": "video",
#        "entity": "face",
#        "ai_model": "face_detection",
#        "confidence": 0.6
#      },
#      {
#        "name": "save_face_action",
#        "act": "save",
#        "type": "video",
#        "interval": 2,
#        "idle": 600
#      }
#    ]

ambianic::config.pipelines.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::config.pipelines.video()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

  local action="${*}"
  local result

  if [ "${action:-null}" != 'null' ]; then
    result="${action}"
  else
    bashio::log.error "Null action"
  fi
  echo ${result:-null}
}

ambianic::config.pipelines()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

  local pipelines=$(jq '.pipelines' ${__BASHIO_DEFAULT_ADDON_CONFIG})

  bashio::log.debug "Pipelines:" $(echo "${pipelines:-null}" | jq '.')

  local result
  local ppls='['

 if [ "${pipelines:-null}" != 'null' ]; then
    local pplnames=$(echo "${pipelines}" | jq -r '.[].name' | sort | uniq)
    local ppls='['
    local k=0
    local type='null'

    bashio::log.debug "Pipeline names: ${pplnames}"

    for pplname in ${pplnames:-}; do
      bashio::log.debug "Pipeline: ${pplname}"
      local action_names=$(jq -r '.pipelines[]|select(.name=="'${pplname}'").action' ${__BASHIO_DEFAULT_ADDON_CONFIG})
      local acts='['
      local j=0

      bashio::log.debug "Pipeline: ${pplname}; actions: ${action_names}"

      for an in ${action_names}; do
        local action=$(jq '.actions[]|select(.name=="'${an}'")' ${__BASHIO_DEFAULT_ADDON_CONFIG})

        bashio::log.debug "Pipeline: ${pplname}; action_name: ${an}; action:" $(echo "${action}" | jq -c '.')

        type=$(echo "${action}" | jq -r '.type')

        case ${type:-null} in
          video)
            act=$(ambianic::config.pipelines.video "${action}")
            ;;
          audio)
            act=$(ambianic::config.pipelines.audio "${action}")
            ;;
          *)
            bashio::log.warning "Invalid pipeline type: ${type}"
            ;;
        esac
        if [ "${act:-null}" = 'null' ]; then
          bashio::log.warning "FAILED to configure pipeline ${pplname}; action ${i}; act: ${j}: ${pipelines}"
        else
          bashio::log.debug "Configured action ${j}: ${act}"
          if [ ${j} -gt 0 ]; then acts="${acts},"; fi
          acts="${acts}${act}"
          j=$((j+1))
        fi
      done

      local ppl='{"name":"'${pplname}'","type":"'${type:-null}'","actions":'"${acts:-null}]"'}'
      bashio::log.debug "Configured pipeline: ${ppl}"

      if [ ${k} -gt 0 ]; then ppls="${ppls},"; fi
      ppls="${ppls}${ppl}"
      k=$((k+1))
    done
    ppls="${ppls}]"
    bashio::log.debug "Pipelines: ${ppls}"
    result="${ppls}"
  else
    bashio::log.notice "No pipelines defined"
  fi
  echo "${result:-null}"
}

###
## CONFIGURATION (read JSON)
###

ambianic::config()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

  local workspace=$(bashio::config 'workspace')
  local result
  
  if [ "${workspace:-null}" != 'null' ]; then

    mkdir -p "${workspace}"
    if [ -d "${workspace}" ]; then
      bashio::log.info "Workspace: ${workspace}"

      local config='{"workspace":"'${workspace}'"}'
      local ok

      # configure ai_models
      ok=$(ambianic::config.ai_models)
      if [ "${ok:-null}" != 'null' ]; then
        bashio::log.debug "AI Models configured:" $(echo "${ok}" | jq -c '.') 
        # record in configuration
        config=$(echo "${config:-null}" | jq '.ai_models='"${ok}")

        # configure sources
        ok=$(ambianic::config.sources)
        if [ "${ok:-null}"  != 'null' ]; then
          bashio::log.debug "Sources configured:" $(echo "${ok}" | jq -c '.') 
          # record in configuration
          config=$(echo "${config:-null}" | jq '.sources='"${ok}")

          # configure pipelines
          ok=$(ambianic::config.pipelines)
          if [ "${ok:-null}" != 'null' ]; then
            bashio::log.debug "Pipelines configured:" $(echo "${ok}" | jq -c '.') 
            # record in configuration
            config=$(echo "${config:-null}" | jq '.pipelines='"${ok}")
            bashio::log.debug "Ambianic configured:" $(echo "${config}" | jq -c '.')
            # success
            result="${config}"
          else
            bashio::log.error "Failed to configure pipelines"
          fi
        else
          bashio::log.error "Failed to configure sources"
        fi
      else
        bashio::log.error "Failed to configure ai_models"
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
## START
###

## start.proxy
ambianic::start.proxy()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}" "${*}"

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
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}"

  local config="${config:-null}"
  local result
  local t=$(mktemp)

  if [ "${config:-null}" != 'null' ]; then
    local ok
    local ambianic

    # update YAML
    ambianic=$(ambianic::update "${config}")

    if [ ! -z "${ambianic:-}" ]; then
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
      bashio::log.error "Ambianic configuration update failed"
    fi
  else
    bashio::log.error "No configuration provided"
  fi

  echo ${result:-null}
}

## start all
ambianic::start()
{
  bashio::log.debug "FUNCTION: ${FUNCNAME[0]}"

  local result
  local config=$(ambianic::config)

  if [ "${config:-null}" != 'null' ]; then
    bashio::log.info "Configuration successful:" $(echo "${config}" | jq -c '.')

    # start ambianic
    local ok=$(ambianic::start.ambianic "${config}")
    if [ "${ok:-null}" != 'null' ]; then
      config=$(echo "${config:-null}" | jq '.ambianic='"${ok}")
      bashio::log.notice "Ambianic started:" $(echo "${config}" | jq '.') 
      # start proxy
      ok=$(ambianic::start.proxy)
      if [ "${ok:-null}" != 'null' ]; then
        config=$(echo "${config:-null}" | jq '.proxy='"${ok}")
        bashio::log.debug "Proxy started:" $(echo "${config}" | jq '.') 
        result=${config}
      else 
        bashio::log.error "Proxy failed to start"
      fi
    else 
      bashio::log.error "Ambianic failed to start"
    fi
  else 
    bashio::log.error "Configuration failed"
  fi
  echo ${result:-null}
}

###
# main
###

main()
{
  local config=$(ambianic::start ${*})

  if [ "${config:-null}" != 'null' ]; then
    while true; do
      local pid=$(echo "${config}" | jq -r '.ambianic.pid')

      if [ "${pid:-null}" != 'null' ]; then
        local this=$(ps --pid ${pid} | tail +2 | awk '{ print $1 }')
  
        if [ "${local:-null}" != 'null' ]; then
          sleep 300
        else
          # start ambianic
          local ok=$(ambianic::start.ambianic "${config}")
          if [ "${ok:-null}" != 'null' ]; then
            config=$(echo "${config:-null}" | jq '.ambianic='"${ok}")
            bashio::log.notice "Ambianic re-started:" $(echo "${config}" | jq '.') 
          else
            bashio::log.error "Failed to re-start Ambianic"
	    break
          fi
        fi
      fi
    done
  else
    bashio::log.error "Ambianic failed to start"
  fi
}

###
## PRE-FLIGHT
###

if [ -z "${AMBIANIC_EDGE:-}" ]; then
  bashio::log.error "AMBIANIC_EDGE is undefined"
  exit 1
fi

if [ ! -d "${AMBIANIC_EDGE}" ]; then
  bashio::log.error "Ambianic not installed; path: ${AMBIANIC_EDGE}"
  exit 1
fi

###
## MAIN
###

bashio::log.notice "STARTING AMBIANIC"

main ${*}
