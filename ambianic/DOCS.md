# &#127968; - `ambianic` _add-on_

This [Home Assistant](http://home-assistant.io) add-on utilizes the [Ambianic project](https://ambianic.ai/) to detect and classify entity(s) in images.  

## Configuration
The Ambianic _addon_ has the following configuration options:

### `sources`
Sources for sensors which can be consumed, e.g. an `RTSP` feed from a web camera.  Sources should be defined with the following attributes:

+ `uri` - the _universal resource identifier_ of the source, e.g. `rtsp://username:password@192.168.1.221/live`
+ `live` - boolean; default: `true`; indicator for whether camera is live or recorded media
+ `type` - enumerated; default: `video`; options: `video`, `audio` - content type of source; only `video` supported currently

### `ai_models`
TensorFlow Lite models which may be executed using `CPU` only or in conjunction with a Google Coral accelerator.  AI models should be defined with the following attributes:

+ `type` - the type of the model; may be `video` or `audio` (n.b. `audio` is currently unimplemented)
+ `labels` - the set of terms used to identify entities
+ `entity` - the entity to be detected; may be `object` or `face`
+ `tflite` - the model installed as part of the Ambianic run-time
+ `edgetpu` - the accelerated version of the `tflite` model
+ `name` - the name of the model

### `pipelines`
Pipelines define a sequential series of _actions_ which are grouped together; the _pipeline_ `name` distinguishes and should be unique for each set of _actions_.

+ `name` - the name of the pipeline; should be repeated for each pipeline _action_
+ `source` -the _source_ of content to feed the pipeline
+ `type` - the type of the model; may be `video` or `audio` (n.b. `audio` is currently unimplemented)
+ `action` - the `name` of the _action_ to be performed

### `actions`

+ `name` - the name of the _action_; should be unique
+ `act` - the function to perform; may be `detect`, `save`, or `send` (n.b. `send` is currently unimplemented)
+ `type` - the type of the model; may be `video` or `audio` (n.b. `audio` is currently unimplemented)
+ `ai_model` - the `name` of the _ai_model_ to utilize; must be defined in `ai_models`
+ `confidence` - the minimum level of confidence for success; range: [0,100)
+ `top_k` - the maximum number of results to return; range: [0-20)

## Example configuration

```
log_level: debug
workspace: /data/ambianic
ai_models:
  - name: mobilenet_v2_coco
    type: video
    entity: object
    top_k: 10
    labels: coco_labels.txt
    tflite: mobilenet_ssd_v2_coco_quant_postprocess.tflite
    edgetpu: mobilenet_ssd_v2_coco_quant_postprocess_edgetpu.tflite
  - name: mobilenet_v2_face
    type: video
    entity: face
    top_k: 2
    labels: coco_labels.txt
    tflite: mobilenet_ssd_v2_face_quant_postprocess.tflite
    edgetpu: mobilenet_ssd_v2_face_quant_postprocess_edgetpu.tflite
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
    uri: 'rtsp://username:password@192.168.1.221/live'
    type: video
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
