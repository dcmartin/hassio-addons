# &#127968; - `ambianic` _add-on_

This [Home Assistant](http://home-assistant.io) add-on utilizes the [Ambianic project](https://ambianic.ai/) to detect and classify entity(s) in images.  

## Status
This _addon_ is built for the following architectures and available in Docker Hub, e.g. [`amd64`](https://hub.docker.com/repository/docker/dcmartin/amd64-addon-ambianic) version.

![](https://img.shields.io/badge/amd64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/amd64-addon-ambianic.svg)](https://microbadger.com/images/dcmartin/amd64-addon-ambianic)[![](https://images.microbadger.com/badges/version/dcmartin/amd64-addon-ambianic.svg)](https://microbadger.com/images/dcmartin/amd64-addon-ambianic)[![](https://img.shields.io/docker/pulls/dcmartin/amd64-addon-ambianic.svg)](https://hub.docker.com/r/dcmartin/amd64-addon-ambianic)

![](https://img.shields.io/badge/aarch64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/aarch64-addon-ambianic.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-ambianic)[![](https://images.microbadger.com/badges/version/dcmartin/aarch64-addon-ambianic.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-ambianic)[![](https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-ambianic.svg)](https://hub.docker.com/r/dcmartin/aarch64-addon-ambianic)

![](https://img.shields.io/badge/armv7-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/armv7-addon-ambianic.svg)](https://microbadger.com/images/dcmartin/armv7-addon-ambianic)[![](https://images.microbadger.com/badges/version/dcmartin/armv7-addon-ambianic.svg)](https://microbadger.com/images/dcmartin/armv7-addon-ambianic)[![](https://img.shields.io/docker/pulls/dcmartin/armv7-addon-ambianic.svg)](https://hub.docker.com/r/dcmartin/armv7-addon-ambianic)

## How to Use
Install using the Home Assistant addon store; add this repository `http://github.com/dcmartin/hassio-addons` to your store and select the `ambianic` _addon_.

## Configuration
The Ambianic _addon_ has the following configuration options (see [DOCS.md](DOCS.md) for more information:

### `sources`
Sources for sensors which can be consumed, e.g. an `RTSP` feed from a web camera.

### `ai_models`
TensorFlow Lite models which may be executed using `CPU` only or in conjunction with a Google Coral accelerator.

### `pipelines`
Pipelines define a sequential series of _actions_ which are grouped together.

### `actions`
Actions are specific functions performed, e.g. `detect`

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
