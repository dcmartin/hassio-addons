# `motion` - detect and classify detected motion

This add-on is for the [Motion package][motionpkg] which provides an extensive set of capabilities to capture video feeds from a variety of sources, including `RSTP`,`HTTP`, and `MJPEG` network cameras.  Please refer to [configuration information](CONFIGURATION.md)

Locally attached USB camera requires specialized version; see [`motion-video0`](../motion-video0/README.md).

## Containers

Architecture|Container|Version|Pulls
:-------|:-------:|:-------:|:-------:|:-------:
![](https://img.shields.io/badge/amd64-yes-green.svg)|[![](https://images.microbadger.com/badges/image/dcmartin/amd64-addon-motion.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion)|[![](https://images.microbadger.com/badges/version/dcmartin/amd64-addon-motion.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion)|[![](https://img.shields.io/docker/pulls/dcmartin/amd64-addon-motion.svg)](https://hub.docker.com/r/dcmartin/amd64-addon-motion)
![](https://img.shields.io/badge/aarch64-yes-green.svg)|[![](https://images.microbadger.com/badges/image/dcmartin/aarch64-addon-motion.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion)|[![](https://images.microbadger.com/badges/version/dcmartin/aarch64-addon-motion.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion)|[![](https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-motion.svg)](https://hub.docker.com/r/dcmartin/aarch64-addon-motion)
![](https://img.shields.io/badge/armv7-yes-green.svg)|[![](https://images.microbadger.com/badges/image/dcmartin/armv7-addon-motion.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion)|[![](https://images.microbadger.com/badges/version/dcmartin/armv7-addon-motion.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion)|[![](https://img.shields.io/docker/pulls/dcmartin/armv7-addon-motion.svg)](https://hub.docker.com/r/dcmartin/armv7-addon-motion)
![](https://img.shields.io/badge/armhf-yes-green.svg)|[![](https://images.microbadger.com/badges/image/dcmartin/armhf-addon-motion.svg)](https://microbadger.com/images/dcmartin/armhf-addon-motion)|[![](https://images.microbadger.com/badges/version/dcmartin/armhf-addon-motion.svg)](https://microbadger.com/images/dcmartin/armhf-addon-motion)|[![](https://img.shields.io/docker/pulls/dcmartin/armhf-addon-motion.svg)](https://hub.docker.com/r/dcmartin/armhf-addon-motion)

## Sample output

![motion sample](motion-sample.png?raw=true "SAMPLE")

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
