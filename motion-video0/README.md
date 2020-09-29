# &#127916; - `motion` Classic _add-on_

This [Home Assistant](http://home-assistant.io) add-on utilizes the [motion project](https://motion-project.github.io/), [YOLO](https://pjreddie.com/darknet/yolo/), and other AI's to detect and classify entity(s) in images.  The _motion project_ software provides an extensive set of capabilities to capture video feeds from a variety of sources, including `RSTP`,`HTTP`, and `MJPEG` network cameras.  Locally attached video sources are also supported (e.g. `/dev/video0`).

## Related

This add-on interacts with additional components and services:

1. [`motion-ai`](http://github.com/dcmartin/motion-ai/tree/master/README.md) - Automated Home Assistant configurator for use with `motion` _addon_ (see below).
1. `MQTT`	Messaging service; use  [`mosquitto`](https://github.com/home-assistant/hassio-addons/tree/master/mosquitto) or [HiveMQ](https://github.com/hassio-addons/addon-mqtt) add-on
1. `FTP` (_optional_) FTP daemon to receive webcam videos; use [`addon-ftp`](https://github.com/hassio-addons/addon-ftp) add-on

In addition, there are three [Open Horizon](http://github.com/dcmartin/open-horizon) AI services specified in the in [`motion-ai`](http://github.com/dcmartin/motion-ai) repository;  they may be used to identify entities, faces, and license plates.

1. [`yolo4motion`](https://github.com/dcmartin/open-horizon/blob/master/services/yolo4motion/README.md) - using the script [`sh/yolo4motion.sh`](http://github.com/dcmartin/motion-ai/tree/master/sh/yolo4motion.sh) 
1. [`face4motion`](https://github.com/dcmartin/open-horizon/blob/master/services/face4motion/README.md) - using the script [`sh/face4motion.sh`](http://github.com/dcmartin/motion-ai/tree/master/sh/face4motion.sh)
1. [`alpr4motion`](https://github.com/dcmartin/open-horizon/blob/master/services/alpr4motion/README.md) - using the script [`sh/alpr4motion.sh`](http://github.com/dcmartin/motion-ai/tree/master/sh/alpr4motion.sh)

## Containers
This _addon_ is built for the following architectures and available in Docker Hub, e.g. [`amd64`](https://hub.docker.com/repository/docker/dcmartin/amd64-addon-motion-video0) version.

![](https://img.shields.io/badge/amd64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/amd64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/amd64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/amd64-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/amd64-addon-motion-video0)

![](https://img.shields.io/badge/aarch64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/aarch64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/aarch64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/aarch64-addon-motion-video0)

![](https://img.shields.io/badge/armv7-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/armv7-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/armv7-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/armv7-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/armv7-addon-motion-video0)

# Configuration
The configuration [instructions](https://github.com/dcmartin/hassio-addons/blob/master/motion-video0/DOCS.md) provide information on all options; however, for brevity there are three components that need to be
defined for successful operation:

+ `mqtt` - the IP address (FQDN), username, password, and port of the `MQTT` broker
+ `group` - identifier for a subset of cameras; _default_: `motion`
+ `device` - unique identifier for each device in the _group_; **shall not** use reserved MQTT characters (e.g. `-,+,#,/`)
+ `client` - identifier for `device` to listen; may be `+` to indicate all devices; _default_: `+`
+ `cameras` - array of individual camera specifications (see below)

## `cameras`

There are three attributes required to integrate a camera into **HA**:

+ `name` - identifier for the camera as defined by the _addon_ (n.b. MQTT topic **reserved** characters)
+ `type` - camera source type; may be `local`, `netcam`, `ftpd`, `mqtt`
+ `netcam_url` - address of live stream for source, e.g. `rtsp://192.168.1.223/live`
+ `netcam_userpass` - authentication credentials for source, e.g. `username:password`

In addition, there are two additional attributes which are optional:

+ `icon` - select from [Material Design Icons](http://materialdesignicons.com/)
+ `w3w` - location of camera as identified by [What3Words](http://what3words.com)

```
[
  {
    "name": "sheshed",
    "type": "netcam",
    "netcam_url": "rtsp://192.168.1.223/live",
    "netcam_userpass": "!secret netcam-userpass",
    "icon": "cctv",
    "w3w": ["varieties","usage","racks"]
  }
]
```

All `MQTT` messages sent use topics beginning with the `group` specified, for example:

+ `<group>/{name}/{camera}` -- JSON payload of motion detected
+ `<group>/{name}/{camera}/lost` -- JSON payload of motion detected
+ `<group>/{name}/{camera}/event/start` -- JSON payload of motion detected
+ `<group>/{name}/{camera}/event/end` -- JSON payload of motion detected
+ `<group>/{name}/{camera}/image` -- JPEG payload of image (**see** `post_pictures`)
+ `<group>/{name}/{camera}/image-average` -- JPEG payload of average event 
+ `<group>/{name}/{camera}/image-blend` -- JPEG payload of blended event (50%)
+ `<group>/{name}/{camera}/image-composite` --  JPEG payload of composite event
+ `<group>/{name}/{camera}/image-animated` -- GIF payload of event
+ `<group>/{name}/{camera}/image-animated-mask` -- GIF payload of event (as B/W mask)

## Sample output

[![motion sample](https://github.com/dcmartin/addon-motion/blob/master/docs/samples/motion-sample.png?raw=true)](http://github.com/dcmartin/addon-motion/docs/samples/motion-sample.png)

# `MQTT`
A `MQTT` broker is required; the default Mosquitto _add-on_ is sufficient, but must be configured with appropriate authentication, for example:

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
