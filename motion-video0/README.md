# &#127916; - `motion-video0` _add-on_

This [Home Assistant](http://home-assistant.io) add-on utilizes the [motion project](https://motion-project.github.io/), [YOLO](https://pjreddie.com/darknet/yolo/), and other AI's to detect and classify entity(s) in images.  The _motion project_ software provides an extensive set of capabilities to capture video feeds from a variety of sources, including `RSTP`,`HTTP`, and `MJPEG` network cameras.  Locally attached USB camera on `/dev/video0` is also supported.

This add-on interacts with additional components and services:

1. [`motion-ai`](http://github.com/dcmartin/motion-ai/tree/master/README.md) - Automated Home Assistant configurator for use with `motion` _addon_ (see below).
1. `MQTT`	Messaging service; use  [`mosquitto`](https://github.com/home-assistant/hassio-addons/tree/master/mosquitto) or [HiveMQ](https://github.com/hassio-addons/addon-mqtt) add-on
1. `FTP` (_optional_) FTP daemon to receive webcam videos; use [`addon-ftp`](https://github.com/hassio-addons/addon-ftp) add-on

In addition, there are three AI services which may be used to identify entities, faces, and license plates.

1. [`yolo4motion`](http://github.com/dcmartin/open-horizon/tree/master/yolo4motion/README.md)  An [Open Horizon](http://github.com/dcmartin/open-horizon) service; use [`sh/yolo4motion.sh`](http://github.com/dcmartin/motion/tree/master/sh/yolo4motion.sh) in [`motion`](http://github.com/dcmartin/motion) 
1. [`face4motion`](http://github.com/dcmartin/open-horizon/tree/master/face4motion/README.md)  An [Open Horizon](http://github.com/dcmartin/open-horizon) service; use [`sh/face4motion.sh`](http://github.com/dcmartin/motion/tree/master/sh/face4motion.sh) in [`motion`](http://github.com/dcmartin/motion) 
1. [`alpr4motion`](http://github.com/dcmartin/open-horizon/tree/master/alpr4motion/README.md)  An [Open Horizon](http://github.com/dcmartin/open-horizon) service; use [`sh/alpr4motion.sh`](http://github.com/dcmartin/motion/tree/master/sh/alpr4motion.sh) in [`motion`](http://github.com/dcmartin/motion) 

### Containers
This _addon_ is built for the following architectures and available in Docker Hub, e.g. [`amd64`](https://hub.docker.com/repository/docker/dcmartin/amd64-addon-motion-video0) version.

![](https://img.shields.io/badge/amd64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/amd64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/amd64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/amd64-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/amd64-addon-motion-video0)

![](https://img.shields.io/badge/aarch64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/aarch64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/aarch64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/aarch64-addon-motion-video0)

![](https://img.shields.io/badge/armv7-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/armv7-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/armv7-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/armv7-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/armv7-addon-motion-video0)

![](https://img.shields.io/badge/armhf-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/armhf-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armhf-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/armhf-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armhf-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/armhf-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/armhf-addon-motion-video0)

## `motion-ai`
The [`motion-ai`](http://github.com/dcmartin/motion-ai) repository provides automated mechanisms to download, install, and configure [Home Assistant](http://home-assistant.io).   The [`webcams.json`](http://github.com/dcmartin/motion/tree/master/motion/webcams.json.tmpl) file defines cameras known to the system; file contents of `[]` indicate none and only discovered will appear.  After modifying and/or creating this file, Home Assistant should be reconfigured.  Run `make restart` in the top-level **HA** directory --  typically `/usr/share/hassio` when using the `motion-ai`installation [instructions](http://github.com/dcmartin/motion-ai/tree/master/docs/INSTALL.md).

There are three attributes required to integrate a camera into **HA**:

+ `name` - identifier for the camera as defined by the _addon_ (n.b. MQTT topic **reserved** characters)
+ `mjpeg_url` - address of live MJPEG stream; local access only by default
+ `username` - authentication for access to MJPEG stream
+ `password` - authentication for access to MJPEG stream

In addition, there are two additional attributes which are optional:

+ `icon` - select from [Material Design Icons](http://materialdesignicons.com/)
+ `w3w` - location of camera as identified by [What3Words](http://what3words.com)

```
[
  {
    "name": "kelispond",
    "mjpeg_url": "http://127.0.0.1:8090/1",
    "username": "!secret motioncam-username",
    "password": "!secret motioncam-password",
    "icon": "xbox",
    "w3w": ["varieties","usage","racks"]
  }
]
```


## `MQTT`
Specify the host and port for sending MQTT messages. 

```
logins:
  - username: username
    password: password
anonymous: false
customize:
  active: false
  folder: mosquitto
certfile: fullchain.pem
keyfile: privkey.pem
require_certificate: false
```

All topics begin with the `devicedb` specified, which defaults to "motion".

+ `<devicedb>/{name}/{camera}` -- JSON payload of motion detected
+ `<devicedb>/{name}/{camera}/lost` -- JSON payload of motion detected
+  `<devicedb>/{name}/{camera}/event/start` -- JSON payload of motion detected
+ `<devicedb>/{name}/{camera}/event/end` -- JSON payload of motion detected
+ `<devicedb>/{name}/{camera}/image` -- JPEG payload of image (**see** `post_pictures`)
+ `<devicedb>/{name}/{camera}/image-average` -- JPEG payload of average event 
+ `<devicedb>/{name}/{camera}/image-blend` -- JPEG payload of blended event (50%)
+ `<devicedb>/{name}/{camera}/image-composite` --  JPEG payload of composite event
+ `<devicedb>/{name}/{camera}/image-animated` -- GIF payload of event
+ `<devicedb>/{name}/{camera}/image-animated-mask` -- GIF payload of event (as B/W mask)

## Sample output

[![motion sample](samples/motion-sample.png?raw=true "SAMPLE")](samples/motion-sample.png)

# Additional information
The Motion package has extensive [documentation][motiondoc] on available parameters.  Almost all parameters are avsailable.
The JSON configuration options are provided using the same name as in the Motion documentation.

## Changelog & Releases
Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors
David C Martin (github@dcmartin.com)

[commits]: https://github.com/dcmartin/hassio-addons/motion/commits/master
[contributors]: https://github.com/dcmartin/hassio-addons/motion/graphs/contributors
[dcmartin]: https://github.com/dcmartin
[issue]: https://github.com/dcmartin/hassio-addons/motion/issues
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[releases]: https://github.com/dcmartin/hassio-addons/motion/releases
[repository]: https://github.com/dcmartin/hassio-addons
[motionpkg]: https://motion-project.github.io]
[motiondoc]: https://motion-project.github.io/motion_config.html
[watsonvr]: https://www.ibm.com/watson/services/visual-recognition
[digitsgit]: https://github.com/nvidia/digits
[digits]: https://developer.nvidia.com/digits

<img width="1" src="http://clustrmaps.com/map_v2.png?cl=ffffff&w=a&t=n&d=xnRKGfiPo38Qx9Qh6xEuzt53jlOosT0wz-h-B5bRcH8"/>
