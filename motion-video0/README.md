# `motion-video0` - detect and classify USB camera

This add-on is for the [Motion package][motionpkg] which provides an extensive set of capabilities to capture video feeds from a variety of sources; the parent [`motion`](http://github.com/dcmartin/hassio-addons/tree/master/motion/README.md). This _version_ requires an attached camera (**`/dev/video0`**), but will also support `RTSP` and `HTTP` cameras.

## Docker containers

![Supports amd64 Architecture][amd64-shield]
[![](https://images.microbadger.com/badges/image/dcmartin/amd64-addon-motion.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/dcmartin/amd64-addon-motion.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion "Get your own version badge on microbadger.com")
[![Docker Pulls][pulls-motion-amd64]][docker-motion-amd64]

![Supports armv7 Architecture][armv7-shield]
[![](https://images.microbadger.com/badges/image/dcmartin/armv7-addon-motion.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/dcmartin/armv7-addon-motion.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion "Get your own version badge on microbadger.com")
[![Docker Pulls][pulls-motion-armv7]][docker-motion-armv7]

![Supports aarch64 Architecture][aarch64-shield]
[![](https://images.microbadger.com/badges/image/dcmartin/aarch64-addon-motion.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/dcmartin/aarch64-addon-motion.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion "Get your own version badge on microbadger.com")
[![Docker Pulls][pulls-motion-aarch64]][docker-motion-aarch64]

[docker-motion-amd64]: https://hub.docker.com/r/dcmartin/amd64-addon-motion
[pulls-motion-amd64]: https://img.shields.io/docker/pulls/dcmartin/amd64-addon-motion.svg
[docker-motion-armv7]: https://hub.docker.com/r/dcmartin/armv7-addon-motion
[pulls-motion-armv7]: https://img.shields.io/docker/pulls/dcmartin/armv7-addon-motion.svg
[docker-motion-aarch64]: https://hub.docker.com/r/dcmartin/aarch64-addon-motion
[pulls-motion-aarch64]: https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-motion.svg

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg

## Example


```
...
group: motion
device: p40
client: p40
timezone: America/Los_Angeles
cameras:
  - name: window
    type: local
    icon: xbox
    device: /dev/video0
    threshold_percent: 1
```

## Sample output

![motion sample](motion-video0-sample.png?raw=true "SAMPLE")

## Changelog & Releases

Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors

David C Martin (github@dcmartin.com)

The original setup of this repository is by [Franck Nijhof][frenck].

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
