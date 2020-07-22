#!/usr/bin/with-contenv bashio

###
## FUNCTIONS
###

## configuration
config()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

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

ambianic::config.sources.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::config.sources.video()
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

          bashio::log.debug "source: ${result}"
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
  bashio::log.trace "${FUNCNAME[0]} ${*}"
  
  local sources=$(jq '.sources' ${__BASHIO_DEFAULT_ADDON_CONFIG})
  local result
  local srcs

  if [ "${sources:-null}" != 'null' ]; then
    local nsource=$(echo "${sources}" | jq '.|length')
    local i=0
    local j=0

    while [ ${i} -lt ${nsource} ]; do
      local source=$(echo "${sources}" | jq '.['${i}']')
      local type=$(echo "${source}" | jq -r '.type')
      local src

      case "${type:-null}" in
        'video'|'image')
          src=$(ambianic::config.sources.video "${source}")
          ;;
        'audio')
          src=$(ambianic::config.sources.audio "${source}")
          ;;
        *)
          bashio::log.warning "Invalid source type: ${type}"
          ;;
      esac
      if [ "${src:-null}" = 'null' ]; then
        bashio::log.warning "Source ${i}; type: ${type}; no source"
      else
        bashio::log.debug "Source ${i}; type: ${type}; source: ${src}"
        if [ ${j} -gt 0 ]; then srcs="${srcs},"; else srcs='['; fi
        srcs="${srcs}${src}"
        j=$((j+1))
      fi
      i=$((i+1))
    done
    if [ ! -z "${srcs:-}" ]; then srcs="${srcs}]"; else srcs='null'; fi
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

## SOURCES

ambianic::update.sources.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local video="${*}"
  local name=$(echo "${video:-null}" | jq -r '.name')
  local type=$(echo "${video:-null}" | jq -r '.type')
  local uri=$(echo "${video:-null}" | jq -r '.uri')
  local live=$(echo "${video:-null}" | jq -r '.live')

  echo "  ${name}:"
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
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local sources="${*}"

  if [ "${sources:-null}" != 'null' ]; then
    local nsource=$(echo "${sources}" | jq '.|length')
    local i=0

    # START OUTPUT
    echo 'sources:'

    while [ ${i} -lt ${nsource} ]; do
      local source=$(echo "${sources}" | jq '.['${i}']')


      if [ "${source:-null}" != 'null' ]; then
        local type=$(echo "${source}" | jq -r '.type')

        bashio::log.debug "Source: ${source}"
        case "${type:-null}" in
          'video'|'image')
            bashio::log.debug "Source: ${i}; type: ${type}"
            ambianic::update.sources.video "${source}"
            ;;
          'audio')
            bashio::log.debug "Source: ${i}; type: ${type}"
            ambianic::update.sources.audio "${source}"
            ;;
          *)
            bashio::log.warning "Source: ${i}; invalid source type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
  else
    bashio::log.error "No sources defined; configuration:" $(echo "${config:-null}" | jq '.')
  fi
}

## AI_MODELS

ambianic::update.ai_models.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.ai_models.video()
{
  bashio::log.trace "${FUNCNAME[0]}"

  local model="${*}"
  local name=$(echo "${model:-null}" | jq -r '.name')
  local labels=$(echo "${model:-null}" | jq -r '.labels')
  local entity=$(echo "${model:-null}" | jq -r '.entity')
  local top_k=$(echo "${model:-null}" | jq -r '.top_k')
  local tflite=$(echo "${model:-null}" | jq -r '.tflite')
  local edgetpu=$(echo "${model:-null}" | jq -r '.edgetpu')

  case "${entity:-null}" in
    'object')
      echo "  ${name}:"
      echo '    model:'
      echo "      tflite: ${AMBIANIC_EDGE}/ai_models/${tflite}"
      echo "      edgetpu: ${AMBIANIC_EDGE}/ai_models/${edgetpu}"
      echo "    labels: ${AMBIANIC_EDGE}/ai_models/${labels}"
      ;;
    'face')
      echo "  ${name}:"
      echo '    model:'
      echo "      tflite: ${AMBIANIC_EDGE}/ai_models/${tflite}"
      echo "      edgetpu: ${AMBIANIC_EDGE}/ai_models/${edgetpu}"
      echo "    labels: ${AMBIANIC_EDGE}/ai_models/${labels}"
      echo '    top_k: '${top_k}
      ;;
    *)
      bashio::log.error "Invalid entity: ${entity}"
      ;;
  esac
}

ambianic::update.ai_models()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local ai_models="${*}"

  if [ "${ai_models:-null}" != 'null' ]; then
    local nai_model=$(echo "${ai_models}" | jq '.|length')
    local i=0

    # START OUTPUT
    echo 'ai_models:'

    while [ ${i} -lt ${nai_model} ]; do
      local ai_model=$(echo "${ai_models}" | jq '.['${i}']')

      bashio::log.debug "ai_model: ${i}" $(echo "${ai_model:-null}" | jq '.')

      if [ "${ai_model:-null}" != 'null' ]; then
        local type=$(echo "${ai_model}" | jq -r '.type')
        local src='null'

        case "${type:-null}" in
          'video')
            ambianic::update.ai_models.video "${ai_model}"
            ;;
          'audio')
            ambianic::update.ai_models.audio "${ai_model}"
            ;;
          *)
            bashio::log.warning "Invalid ai_model type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
  else
    bashio::log.error "No ai_models defined; configuration:" $(echo "${config:-null}" | jq '.')
  fi
}

## PIPELINES

ambianic::update.pipelines.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.pipelines.video.send()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::update.pipelines.video.detect()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local act="${*}"
  local ai_model=$(echo "${act:-null}" | jq -r '.ai_model')
  local entity=$(echo "${act:-null}" | jq -r '.entity')
  local confidence=$(echo "${act:-null}" | jq -r '.confidence')

  case "${entity:-null}" in
    'object')
      bashio::log.debug "ai_model: ${ai_model}; entity: ${entity}; confidence: ${confidence}"
      echo '    - detect_objects:'
      echo '        ai_model: '${ai_model}
      echo '        confidence_threshold: '${confidence}
      ;;
    'face')
      bashio::log.debug "ai_model: ${ai_model}; entity: ${entity}; confidence: ${confidence}"
      echo '    - detect_faces:'
      echo '        ai_model: '${ai_model}
      echo '        confidence_threshold: '${confidence}
      ;;
    *)
      bashio::log.warning "Action: ${name}; invalid entity: ${entity}"
      ;;
  esac
}

ambianic::update.pipelines.video.save()
{
  bashio::log.debug "${FUNCNAME[0]} ${*}"

  local act="${*}"
  local interval=$(echo "${act:-null}" | jq -r '.interval')
  local idle=$(echo "${act:-null}" | jq -r '.idle')

  echo '    - save_detections:'
  echo '        positive_interval: '${interval}
  echo '        idle_interval: '${idle}
}

ambianic::update.pipelines.video()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local pipeline="${*}"
  local name=$(echo "${pipeline:-null}" | jq -r '.name')
  local actions=$(echo "${pipeline:-null}" | jq '.actions')
  local source=$(echo "${pipeline:-null}" | jq -r '.source')
  local naction=$(echo "${actions:-null}" | jq '.|length')

  if [ ! -z "${name:-}" ] && [ ! -z "${source:-}" ] && [ "${actions:-null}" != 'null' ]; then
    local i=0

    bashio::log.debug "Pipeline: ${name}; source: ${source}; actions: ${naction}"

    # start output
    echo '  '${name}':'
    echo '    - source: '${source}

    while [ ${i} -lt ${naction} ]; do
      local action=$(echo "${actions}" | jq '.['${i}']')

      if [ "${action:-null}" != 'null' ]; then
        local act=$(echo "${action}" | jq -r '.act')

        bashio::log.debug "Pipeline: ${name}; action ${i}; act: ${act}"

        case "${act:-null}" in
          'detect')
            bashio::log.debug "Action: ${i}; act: ${action}"
            ambianic::update.pipelines.video.detect "${action}"
            ;;
          'save')
            bashio::log.debug "Action: ${i}; act: ${action}"
            ambianic::update.pipelines.video.save "${action}"
            ;;
          'send')
            bashio::log.debug "Action: ${i}; act: ${act}"
            ambianic::update.pipelines.video.send "${action}"
            ;;
          *)
            bashio::log.warning "Action: ${i}; invalid act: ${act}"
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
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local pipelines="${*}"

  if [ "${pipelines:-null}" != 'null' ]; then
    local npipeline=$(echo "${pipelines}" | jq '.|length')
    local i=0

    # START OUTPUT
    echo 'pipelines:'

    while [ ${i} -lt ${npipeline} ]; do
      local pipeline=$(echo "${pipelines}" | jq '.['${i}']')

      if [ "${pipeline:-null}" != 'null' ]; then
        local type=$(echo "${pipeline}" | jq -r '.type')

        case "${type:-null}" in
          'video')
            bashio::log.debug "Pipeline: ${i}; type: ${type}"
            ambianic::update.pipelines.video "${pipeline}"
            ;;
          'audio')
            bashio::log.debug "Pipeline: ${i}; type: ${type}"
            ambianic::update.pipelines.audio "${pipeline}"
            ;;
          *)
            bashio::log.warning "Pipeline: ${i}; invalid pipline type: ${type}"
            ;;
        esac
      fi
      i=$((i+1))
    done
  else
    bashio::log.notice "No pipelines defined; configuration:" $(echo "${config:-null}" | jq '.')
  fi
}

###
## CONFIGURE (read JSON)
###

ambianic::config.ai_models.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::config.ai_models.video()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local model="${*}"
  local name=$(echo "${model:-null}" | jq -r '.name')
  local entity=$(echo "${model:-null}" | jq -r '.entity')
  local result

  if [ "${name:-null}" != 'null' ] && [ "${entity:-null}" != 'null' ]; then
    local labels=$(echo "${model:-null}" | jq -r '.labels')
    if [ "${labels:-null}" != 'null' ]; then
      local top_k=$(echo "${model:-null}" | jq -r '.top_k')
      if [ "${top_k:-null}" != 'null' ]; then
        local tflite=$(echo "${model:-null}" | jq -r '.tflite')
        local edgetpu=$(echo "${model:-null}" | jq -r '.edgetpu')

        if [ "${tflite:-null}" != 'null' ] && [ "${edgetpu:-null}" != 'null' ]; then
          result='{"type":"video","entity":"'${entity}'","name":"'${name}'","labels":"'${labels}'","top_k":"'${top_k}'","edgetpu":"'${edgetpu}'","tflite":"'${tflite}'"}'
          bashio::log.debug "ai_model: ${result}"
        else
          bashio::log.error "EdgeTPU and/or TFlite model unspecified: ${model}"
        fi
      else
        bashio::log.error  "TopK unspecified: ${model}"
      fi
    else
      bashio::log.error  "Labels unspecified: ${model}"
    fi
  else
    bashio::log.error  "Name and/or entity unspecified: ${model}"
  fi
  echo ${result:-null}
}

ambianic::config.ai_models()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local ai_models=$(jq '.ai_models' ${__BASHIO_DEFAULT_ADDON_CONFIG})
  local result
  local models='['

  if [ "${ai_models:-null}" != 'null' ]; then
    local nmodel=$(echo "${ai_models}" | jq '.|length')
    local i=0
    local j=0

    while [ ${i:-0} -lt ${nmodel:-0} ]; do
      local model=$(echo "${ai_models}" | jq '.['${i}']')
      local type=$(echo "${model}" | jq -r '.type')
      local model

      case "${type:-null}" in
        'video')
          bashio::log.debug "ai_model ${i}; type: ${type}"
          model=$(ambianic::config.ai_models.video "${model}")
          ;;
        'audio')
          bashio::log.debug "ai_model ${i}; type: ${type}"
          model=$(ambianic::config.ai_models.audio "${model}")
          ;;
        *)
          bashio::log.warning "ai_model ${i}; invalid type: ${type}"
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
## configure
##

ambianic::config.pipelines.audio()
{
  bashio::log.warning "NOT IMPLEMENTED" "${FUNCNAME[0]}" "${*}"
}

ambianic::config.pipelines.video()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local action="${*}"
  local name=$(echo "${action:-null}" | jq -r '.name')
  local act=$(echo "${action:-null}" | jq -r '.act')
  local result

  case "${act:-null}" in
    'detect')
      # test for all detect attributes
      bashio::log.debug "Action: ${name}; act: ${act}"
      result=$(echo "${action}" | jq '{"act":.act,"type":.type,"entity":.entity,"ai_model":.ai_model,"confidence":.confidence}')
      ;;
    'save')
      # test for all save attributes
      bashio::log.debug "Action: ${name}; act: ${act}"
      result=$(echo "${action}" | jq '{"act":.act,"type":.type,"entity":.entity,"interval":.interval,"idle":.idle}')
      ;;
    *)
      bashio::log.warning "Action: ${name}; invalid act: ${act}"
      ;;
  esac
  echo ${result:-null}
}

ambianic::config.pipelines()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local pipelines=$(jq '.pipelines' ${__BASHIO_DEFAULT_ADDON_CONFIG})

  bashio::log.trace "pipelines:" $(echo "${pipelines:-null}" | jq '.')

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
      local steps=$(echo "${pipelines}" | jq '[.[]|select(.name=="'${pplname}'")]')
      local acts=''
      local i=0
      local j=0
      local source

      # should be unique
      local action_names=$(echo "${steps:-null}" | jq -r '.[].action')
      local all_actions=$(jq '.actions' ${__BASHIO_DEFAULT_ADDON_CONFIG})

      bashio::log.debug "Pipeline: ${pplname}; actions: ${action_names}"

      for an in ${action_names}; do
        local action=$(echo "${all_actions}" | jq '.[]|select(.name=="'${an}'")')
        local src=$(echo "${steps:-null}" | jq -r '.['${i}'].source')
        local act='null'

        type=$(echo "${action}" | jq -r '.type')

        case "${type:-null}" in
          'video')
            act=$(ambianic::config.pipelines.video "${action}")
            bashio::log.debug "Pipeline ${k}: ${pplname}; action: ${an}; type: ${type}"
            ;;
          'audio')
            bashio::log.debug "Pipeline ${k}: ${pplname}; action: ${an}; type: ${type}"
            act=$(ambianic::config.pipelines.audio "${action}")
            ;;
          *)
            bashio::log.warning "Invalid pipeline type: ${type}"
            ;;
        esac
        if [ "${act:-null}" = 'null' ]; then
          bashio::log.warning "FAILED: Pipeline ${k}: ${pplname}; action ${i}: ${an}"
        else
          if [ "${src:-null}" != 'null' ]; then
            bashio::log.debug "Pipeline ${k}: ${pplname}; action ${i}: ${an}; source: ${src}"
            source="${src}"
#            act=$(echo "${act:-null}" | jq '.source="'${source}'"')
          else
            bashio::log.debug "Pipeline ${k}: ${pplname}; action ${i}: ${an}; no source"
          fi 
          bashio::log.debug "Pipeline ${k}: ${pplname}; action ${i}: ${an}; adding ${j}:" $(echo "${act}" | jq '.')
          if [ ${j} -gt 0 ]; then acts="${acts},"; else acts='['; fi
          acts="${acts}${act}"
          j=$((j+1))
        fi
        i=$((i+1))
      done
      if [ ${j} -gt 0 ]; then 
        acts="${acts}]"
      else
        bashio::log.warning "Pipeline ${k}: ${pplname}; no actions"
        acts='null'
      fi

      local ppl='{"name":"'${pplname}'","type":"'${type:-null}'","source":"'${source}'","actions":'"${acts:-null}"'}'

      bashio::log.debug "Configured pipeline:" $(echo "${ppl}" | jq '.')

      if [ ${k} -gt 0 ]; then ppls="${ppls},"; fi
      ppls="${ppls}${ppl}"
      k=$((k+1))
    done
    ppls="${ppls}]"
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
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

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
        bashio::log.debug "AI Models configured:" $(echo "${ok}" | jq '.') 
        # record in configuration
        config=$(echo "${config:-null}" | jq '.ai_models='"${ok}")

        # configure sources
        ok=$(ambianic::config.sources)
        if [ "${ok:-null}"  != 'null' ]; then
          bashio::log.debug "Sources configured:" $(echo "${ok}" | jq '.') 
          # record in configuration
          config=$(echo "${config:-null}" | jq '.sources='"${ok}")

          # configure pipelines
          ok=$(ambianic::config.pipelines)
          if [ "${ok:-null}" != 'null' ]; then
            # record in configuration
            config=$(echo "${config:-null}" | jq '.pipelines='"${ok}")
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
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

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

## ALL
ambianic::update()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local config="${*}"
  local workspace=$(echo "${config}" | jq -r '.workspace')
  local ambianic="${workspace}/config.yaml"
  local secrets="${workspace}/secrets.yaml"
  local logging=${workspace}/ambianic-log.txt
  local timeline=${workspace}/timeline-event-log.yaml
  local loglevel=${__BASHIO_LOG_LEVEL:-${__BASHIO_LOG_LEVEL_ALL:-9}}
  local result

  # clean logging
  rm -f ${logging}
  touch ${logging}

  # clean timeline
  rm -f ${timeline}
  touch ${timeline}

  # start secrets
  rm -f ${secrets}
  touch ${secrets}

  # start config
  rm -f ${ambianic}
  touch ${ambianic}

  # version of ambianic-edge 
  echo "version: '1.3.29'" >> ${ambianic}

  # data directory
  echo "data_dir: &data_dir ${workspace}" >> ${ambianic}

  # logging
  echo "logging:" >> ${ambianic}
  echo "  file: ${logging}" >> ${ambianic}
  # translate from
  if [ ${loglevel} -le ${__BASHIO_LOG_LEVEL_ERROR} ]; then
    loglevel='ERROR'
  elif [ ${loglevel} -le ${__BASHIO_LOG_LEVEL_WARNING} ]; then
    loglevel='WARNING'
  elif [ ${loglevel} -le ${__BASHIO_LOG_LEVEL_INFO} ]; then
    loglevel='INFO'
  else 
    # default DEBUG
    loglevel='DEBUG'
  fi
  echo "  level: ${loglevel}" >> ${ambianic}

  # timeline
  echo "timeline:" >> ${ambianic}
  echo "  event_log: ${timeline}" >> ${ambianic}

  # sources
  ambianic::update.sources $(echo "${config}" | jq '.sources') >> ${ambianic}

  # ai_models
  ambianic::update.ai_models $(echo "${config}" | jq '.ai_models') >> ${ambianic}

  # pipelines
  ambianic::update.pipelines $(echo "${config}" | jq '.pipelines') >> ${ambianic}

  result='{"logging":"'${logging:-}'","loglevel":"'${loglevel:-}'","timeline":"'${timeline:-}'","path":"'${ambianic:-}'"}'

  echo ${result:-null}
}

## start.ambianic
ambianic::start.ambianic()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local config="${config:-null}"
  local update 
  local result

  if [ "${config:-null}" != 'null' ]; then
    # update YAML
    update=$(ambianic::update "${config}")
    if [ "${update:-null}" != 'null' ]; then 
      local ambianic=$(echo "${update}" | jq -r '.path')

      if [ ! -z "${ambianic:-}" ] && [ -e "${ambianic}" ]; then
        bashio::log.debug "${FUNCNAME[0]}: configuration YAML: ${ambianic}"
        local workspace=$(echo "${config}" | jq -r '.workspace')

        if [ -d "${workspace:-null}" ]; then
          bashio::log.debug "${FUNCNAME[0]}: workspace: ${workspace}"
          local t=$(mktemp)
          local pid

          # change to working directory
          pushd ${workspace} &> /dev/null
          # start python3
          export AMBIANIC_DIR=${workspace}
          export DEFAULT_DATA_DIR=${workspace}/data
	  mkdir -p ${DEFAULT_DATA_DIR}
	  python3 -m ambianic &> ${t} &
          # test
          pid=$!; if [ ${pid:-0} -gt 0 ]; then
            bashio::log.debug "${FUNCNAME[0]}: started; pid: ${pid}"
            result='{"config":'"${update}"',"pid":'${pid}',"out":"'${t}'"}'
          else
            bashio::log.error "${FUNCNAME[0]}: failed to start"
            rm -f ${t}
          fi
          # return
          popd &> /dev/null
        else
          bashio::log.error "${FUNCNAME[0]}: no workspace directory: ${workspace:-}"
        fi
      else
        bashio::log.error "${FUNCNAME[0]}: no configuration file: ${ambianic:-}"
      fi
    else
      bashio::log.error "${FUNCNAME[0]}: update failed"
    fi
  else
    bashio::log.error "${FUNCNAME[0]}: no configuration"
  fi
  echo "${result:-null}"
}

## start all
ambianic::start()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local config="${*}"
  local result

  if [ "${config:-null}" != 'null' ]; then
    local ok
    # start ambianic
    ok=$(ambianic::start.ambianic "${config}")
    if [ "${ok:-null}" != 'null' ]; then
      bashio::log.info "${FUNCNAME[0]}: ambianic started:" $(echo "${ok}" | jq '.') 
      # update config
      config=$(echo "${config:-null}" | jq '.ambianic='"${ok}")
      # start proxy
      ok=$(ambianic::start.proxy)
      if [ "${ok:-null}" != 'null' ]; then
        bashio::log.info "${FUNCNAME[0]}: Proxy started:" $(echo "${ok}" | jq '.') 
        # update config
        result=$(echo "${config:-null}" | jq '.proxy='"${ok}")
      else 
        bashio::log.error "${FUNCNAME[0]}: Proxy failed to start"
      fi
    else 
      bashio::log.error "${FUNCNAME[0]}: Ambianic failed to start: ${ok}"
    fi
  else 
    bashio::log.error "${FUNCNAME[0]}: No configuration"
  fi
  echo ${result:-null}
}

###
# main
###

main()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"
  local tailen=${AMBIANIC_LOG_TAIL:-100}
  local config

  bashio::log.info "Configuring ambianic ..."
  config=$(ambianic::config)

  if [ "${config:-null}" != 'null' ]; then
    bashio::log.notice "${FUNCNAME[0]}: Ambianic configured:" $(echo "${config}" | jq '.')

    local out
    local pid
    local result=$(ambianic::start ${config})

    # record for posterity
    echo "${result}" | jq '.' > "/var/run/ambianic.json"

    bashio::log.debug "${FUNCNAME[0]}: ambianic::start result: ${result}"

    pid=$(echo "${result:-null}" | jq -r '.ambianic.pid')

    while true; do
      pid=$(echo "${result:-null}" | jq -r '.ambianic.pid')
 
      if [ "${pid:-null}" != 'null' ]; then
        local this=$(ps --pid ${pid} | tail +2 | awk '{ print $1 }')
  
        if [ "${this:-null}" == "${pid}" ]; then
          bashio::log.notice "${FUNCNAME[0]}: Ambianic PID: ${this}; running"

          out=$(echo "${result}" | jq -r '.ambianic.out')
          if [ -s "${out:-null}" ]; then 
            bashio::log.green "${FUNCNAME[0]}: AMBIANIC OUTPUT"
	    tail -${tailen}  "${out}" >&2
          else 
            bashio::log.info "${FUNCNAME[0]}: ambianic output empty: ${out}"
          fi

          out=$(echo "${result}" | jq -r '.workspace')/ambianic-log.txt
          if [ -s "${out:-null}" ]; then 
            bashio::log.green "${FUNCNAME[0]}: AMBIANIC LOG"
	    tail -${tailen} "${out}" >&2
          else 
            bashio::log.info "${FUNCNAME[0]}: empty output: ${out}"
          fi

          out=$(echo "${result}" | jq -r '.proxy.out')
          if [ -s "${out:-null}" ]; then 
            bashio::log.green "${FUNCNAME[0]}: PERRJS OUTPUT"
	    tail -${tailen} "${out}" >&2
          else 
            bashio::log.info "${FUNCNAME[0]}: proxy output empty: ${out}"
          fi

          bashio::log.info "${FUNCNAME[0]}: watchdog sleeping for ${AMBIANIC_WATCHDOG_SECONDS:-30} seconds..."
          sleep ${AMBIANIC_WATCHDOG_SECONDS:-30}
        else
          bashio::log.warning "${FUNCNAME[0]}: Ambianic PID: ${pid}; not running"

          # configuration debugging
          out=$(echo "${result}" | jq -r '.ambianic.config.path')
          echo "Ambianic configuation YAML: ${out}" >&2
          if [ -e "${out}" ]; then cat "${out}" >&2; else echo "No file: ${out}" >&2; fi
  
          # cleanup ambianic
          out=$(echo "${result}" | jq -r '.ambianic.out')
          echo "Ambianic log: ${out}" >&2
          if [ -e "${out}" ]; then cat "${out}" >&2; else echo "No file: ${out}" >&2; fi
          rm -f "${out}"

          # cleanup proxy
          out=$(echo "${result}" | jq -r '.proxy.out')
          echo "Proxy log: ${out}" >&2
          if [ -e "${out}" ]; then cat "${out}" >&2; else echo "No file: ${out}" >&2; fi
          kill -9 $(echo "${result}" | jq -r '.proxy.pid')
          rm -f ${out}

	  # restart ambianic
          result=$(ambianic::start ${config})
	  
	  # record for posterity
	  echo "${result}" | jq '.' > "/var/run/ambianic.json"
        fi
      else
        bashio::log.error "${FUNCNAME[0]}: Ambianic failed to start"
        break
      fi
    done
  else
    bashio::log.error "${FUNCNAME[0]}: Ambianic configuration failed"
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
