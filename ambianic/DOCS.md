# &#127968; - Ambianic Edge

## Description
This _addon_ for Home Assistant utilizes artificial intelligence at the edge (i.e. on this device) to detect and classify entities of interest.  AI's using Google TensorFlow Lite run either CPU-only or using USB-attached **Coral TPU**.

## `sources`
Sources for sensors which can be consumed, e.g. an `RTSP` feed from a web camera.  Sources should be defined with the following attributes:

+ `name` - the name of the _source_; should be unique (e.g. `camera1`)
+ `uri` - the _universal resource identifier_ of the source, e.g. `rtsp://username:password@192.168.1.221/live`
+ `live` - boolean; default: `true`; indicator for whether camera is live or recorded media
+ `type` - enumerated;  content type of source; options: `video`, `image`, `audio`

## `ai_models`
TensorFlow Lite models which may be executed using `CPU` only or in conjunction with a Google Coral accelerator.  AI models should be defined with the following attributes:

+ `name` - the name of the model; should be unique (e.g. `mobilenet_ssd_v2_face`)
+ `type` - the type of the model; may be `video` or `audio` (n.b. `audio` is currently unimplemented)
+ `labels` - the set of terms used to identify entities
+ `entity` - the entity to be detected; may be `object` or `face`
+ `tflite` - the model installed as part of the Ambianic run-time
+ `top_k` - the maximum number of results to return; range: (1-20)

### `tflite`

1. `inception_v1_224_quant`
1. `inception_v2_224_quant`
1. `inception_v3_299_quant`
1. `inception_v4_299_quant`
1. `mobilenet_ssd_v1_coco_quant_postprocess`
1. `mobilenet_ssd_v2_coco_quant_postprocess`
1. `mobilenet_ssd_v2_face_quant_postprocess`
2. `mobilenet_v1_1.0_224_quant`
2. `mobilenet_v1_1.0_224_quant_embedding_extractor`
2. `mobilenet_v2_1.0_224_inat_bird_quant`
2. `mobilenet_v2_1.0_224_inat_insect_quant`
2. `mobilenet_v2_1.0_224_inat_plant_quant`
2. `mobilenet_v2_1.0_224_quant`

### `labels`

1. `coco`
1. `imagenet`
1. `inat_bird`
1. `inat_insect`
1. `inat_plant`
1. `pet`

## `pipelines`
Pipelines define a sequential series of _actions_ which are grouped together; the _pipeline_ `name` distinguishes and should be unique for each set of _actions_.

+ `name` - the name of the pipeline; should be repeated for each pipeline _action_ (e.g. `pipeline1`)
+ `source` -the _source_ of content to feed the pipeline
+ `type` - the type of the model; may be `video` or `audio` (n.b. `audio` is currently unimplemented)
+ `action` - the `name` of the _action_ to be performed

## `actions`

+ `name` - the name of the _action_; should be unique (e.g. `saveAction`)
+ `act` - the function to perform; may be `detect`, `save`, or `send` (n.b. `send` is currently unimplemented)
+ `type` - the type of the model; may be `video` or `audio` (n.b. `audio` is currently unimplemented)
+ `ai_model` - the `name` of the _ai_model_ to utilize; must be defined in `ai_models`
+ `confidence` - the minimum level of confidence for success; range: [0,100)

## Example configuration

```
log_level: info
workspace: /data/ambianic
ai_models:
  - name: mobilenet_v2_coco
    type: video
    entity: object
    top_k: 10
    labels: coco
    tflite: mobilenet_ssd_v2_coco_quant_postprocess
  - name: mobilenet_v2_face
    type: video
    entity: face
    labels: coco
    top_k: 2
    tflite: mobilenet_ssd_v2_face_quant_postprocess
pipelines:
  - name: pipeline1
    source: camera1
    type: video
    action: detectObject
  - name: pipeline1
    type: video
    action: saveObject
  - name: pipeline1
    source: camera1
    type: video
    action: detectFace
  - name: pipeline1
    type: video
    action: saveFace
actions:
  - name: detectObject
    act: detect
    type: video
    entity: object
    ai_model: mobilenet_v2_coco
    confidence: 0.6
  - name: saveObject
    act: save
    type: video
    entity: object
    interval: 2
    idle: 600
  - name: detectFace
    act: detect
    type: video
    entity: face
    ai_model: mobilenet_v2_face
    confidence: 0.6
  - name: saveFace
    act: save
    type: video
    entity: face
    interval: 2
    idle: 600
sources:
  - name: camera1
    uri: 'http://192.168.1.163/img/snapshot.cgi'
    type: image
    live: true
```

## Changelog & Releases
Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors
David C Martin (github@dcmartin.com)

[commits]: https://github.com/dcmartin/hassio-addons/ambianic/commits/master
[contributors]: https://github.com/dcmartin/hassio-addons/ambianic/graphs/contributors
[dcmartin]: https://github.com/dcmartin
[issue]: https://github.com/dcmartin/hassio-addons/ambianic/issues
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[releases]: https://github.com/dcmartin/hassio-addons/ambianic/releases
[repository]: https://github.com/dcmartin/hassio-addons

<img width="1" src="http://clustrmaps.com/map_v2.png?cl=ffffff&w=a&t=n&d=nHYT4NR2G2QC7Y7yBZRLYccEBA0WFVBI5AgkTmURk9c"/>
