# &#127916; `ambianic` configuration 

The following section details the attributes which may be used to configure the _addon_.

## `ai_models`

## `sources`

## `actions`

## `pipelines`

## `group`, `device`, and `client`
The _identifiers_ distinguish collections as well as individuals; camera identifiers _must_ be unique across the group.

+ `group` - identifier for collection of devices; default: `ambianic`
+ `device` - identifier for the computer; default: _none_
+ `client` - limits topic subscriptions to one or all (n.b. `+`) devices

&#9995; **Identifiers** may **ONLY** include lower-case letters (`a-z`), numbers (`0-9`), and _underscore_ (`_`).

## `mqtt`
+ `mqtt.host` - if using a single MQTT broker on a LAN, utilize the TCP/IPv4 addresss, e.g. `192.168.1.40`.
+ `mqtt.port` - TCP/IP port number; default: `1883`
+ `mqtt.username` - credentials for access to broker; default: _none_
+ `mqtt.password` - credentials for access to broker; default: _none_

### Example
```
log_level: info
workspace: /data/ambianic
ai_models:
  - name: entity_detection
    type: video
    top_k: 10
    labels: '${AMBIANIC_PATH}/ai_models/coco_labels.txt'
    tflite: '${AMBIANIC_PATH}/ai_models/mobilenet_ssd_v2_coco_quant_postprocess.tflite'
  - name: face_detection
    type: video
    top_k: 2
    labels: '${AMBIANIC_PATH}/ai_models/coco_labels.txt'
    tflite: '${AMBIANIC_PATH}/ai_models/mobilenet_ssd_v2_face_quant_postprocess.tflite'
pipelines:
  - source: camera1
    type: video
    action: detect_object_action
  - source: detect_object_action
    type: video
    action: save_object_action
  - source: camera2
    type: video
    action: detect_face_action
  - source: detect_face_action
    type: video
    action: save_face_action
actions:
  - name: detect_object_action
    act: detect
    type: video
    entity: object
    ai_model: entity_detection
    confidence: 0.6
  - name: save_object_action
    act: save
    type: video
    interval: 2
    idle: 600
  - name: detect_face_action
    act: detect
    type: video
    entity: face
    ai_model: face_detection
    confidence: 0.6
  - name: save_face_action
    act: save
    type: video
    interval: 2
    idle: 600
sources:
  - name: camera1
    uri: 'rtsp://username:password@192.168.1.221/live'
    type: video
    live: true
  - name: camera2
    uri: 'rtsp://username:password@192.168.1.222/live'
    type: video
    live: true
```
