# Home Assistant add-on - `motion`

This [Home Assistant](http://home-assistant.io) add-on utilizes the [motion project][motionpkg], and [YOLO](https://pjreddie.com/darknet/yolo/) to detect and classify entity(s) in images.  The _motion project_ software provides an extensive set of capabilities to capture video feeds from a variety of sources, including `RSTP`,`HTTP`, and `MJPEG` network cameras.  Locally attached USB camera requires specialized version; see [`motion-video0`](http://github.com/dcmartin/hassio-addons/tree/master/motion-video0/README.md).

This add-on interacts with additional services:

1. [`yolo4motion`](http://github.com/dcmartin/open-horizon/tree/master/yolo4motion/README.md)  An [Open Horizon](http://github.com/dcmartin/open-horizon) service; use [`sh/yolo4motion.sh`](http://github.com/dcmartin/horizon.dcmartin.com/tree/master/sh/yolo4motion.sh) to start Docker container
1. `MQTT`	Messaging service; use  [`mosquitto`](https://github.com/home-assistant/hassio-addons/tree/master/mosquitto) or [HiveMQ](https://github.com/hassio-addons/addon-mqtt) add-on
1. `FTP` (_optional_) FTP daemon to receive videos from webcams (e.g. Linksys WCV80n); use [`addon-ftp`](https://github.com/hassio-addons/addon-ftp) add-on

## Containers

![](https://img.shields.io/badge/amd64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/amd64-addon-motion.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion)[![](https://images.microbadger.com/badges/version/dcmartin/amd64-addon-motion.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion)[![](https://img.shields.io/docker/pulls/dcmartin/amd64-addon-motion.svg)](https://hub.docker.com/r/dcmartin/amd64-addon-motion)

![](https://img.shields.io/badge/aarch64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/aarch64-addon-motion.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion)[![](https://images.microbadger.com/badges/version/dcmartin/aarch64-addon-motion.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion)[![](https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-motion.svg)](https://hub.docker.com/r/dcmartin/aarch64-addon-motion)

![](https://img.shields.io/badge/armv7-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/armv7-addon-motion.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion)[![](https://images.microbadger.com/badges/version/dcmartin/armv7-addon-motion.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion)[![](https://img.shields.io/docker/pulls/dcmartin/armv7-addon-motion.svg)](https://hub.docker.com/r/dcmartin/armv7-addon-motion)

![](https://img.shields.io/badge/armhf-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/armhf-addon-motion.svg)](https://microbadger.com/images/dcmartin/armhf-addon-motion)[![](https://images.microbadger.com/badges/version/dcmartin/armhf-addon-motion.svg)](https://microbadger.com/images/dcmartin/armhf-addon-motion)[![](https://img.shields.io/docker/pulls/dcmartin/armhf-addon-motion.svg)](https://hub.docker.com/r/dcmartin/armhf-addon-motion)

## `MQTT`

This add-on produces the following topics; all topics begin with the `group` specified, which defaults to "motion".

+ `{group}/{device}/start` - device start-up
+ `{group}/{device}/{camera}/lost` - device lost
+ `{group}/{device}/{camera}/found` - device found
+ `{group}/{device}/{camera}/event/start` - start of event
+ `{group}/{device}/{camera}/event/end` - end of event
+ `{group}/{device}/{camera}/image` - JPEG; each image
+ `{group}/{device}/{camera}/image/end` - JPEG; selected event image (**see** `post_pictures`)
+ `{group}/{device}/{camera}/image-average` - JPEG; average image
+ `{group}/{device}/{camera}/image-blend` - JPEG; blended image (50%)
+ `{group}/{device}/{camera}/image-composite` - JPEG; composite image 
+ `{group}/{device}/{camera}/image-animated` - GIF; animation
+ `{group}/{device}/{camera}/image-animated-mask` - GIF; animation mask

Topics may be processed using `MQTT` _sensors_ in Home Assistant;  a configuration [example](http://github.com/dcmartin/motion-config-monitor) and automated [builder](http://github.com/dcmartin/horizon.dcmartin.com)  is provided in other repositories.

## Configuration
Please refer to [configuration information](http://github.com/dcmartin/hassio-addons/tree/master/motion/CONFIGURATION.md)

### Camera specification (examples)

#### `MJPEG`
```
  - name: shedcam
    type: netcam
    icon: window-shutter-open
    width: 640
    height: 480
    netcam_url: 'mjpeg://192.168.1.92:8090/1'
    netcam_userpass: 'username:password'
    threshold_percent: 1
```

#### `RTSP`
```
  - name: testcam
    type: netcam
    icon: webcam
    framerate: 3
    netcam_url: 'rtsp://192.168.93.3/live'
    threshold_percent: 1
    netcam_userpass: 'username:password'
    width: 1920
    height: 1080
```

#### `HTTP`
```
  - name: road
    netcam_url: 'http://192.168.1.36:8081/img/video.mjpeg'
    type: netcam
    icon: road
    netcam_userpass: 'username:password'
    width: 640
    height: 480
```

#### `FTPD`
```
  - name: backyard
    type: ftpd
    netcam_url: 'http://192.168.1.183/img/video.mjpeg'
    icon: texture-box
    netcam_userpass: '!secret netcam-userpass'
```

## Sample output

[![motion sample](motion-sample.png?raw=true "SAMPLE")](http://github.com/dcmartin/hassio-addons/tree/master/motion/motion-sample.png)

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

[watsonvr]: https://www.ibm.com/watson/services/visual-recognition
[digitsgit]: https://github.com/nvidia/digits
[digits]: https://developer.nvidia.com/digits
