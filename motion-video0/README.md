# &#127916;  -  `motion-video0` _add-on_

This [Home Assistant](http://home-assistant.io) _add-on_ is specialized from the [`motion`](http://github.com/dcmartin/hassio-addons/tree/master/motion/README.md) add-on, to include access to `/dev/vide0`; this change **requires** an attached camera on that device, but supports all [configuration](http://github.com/dcmartin/hassio-addons/tree/master/motion/CONFIGURATION.md) options.

## Containers

![](https://img.shields.io/badge/amd64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/amd64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/amd64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/amd64-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/amd64-addon-motion-video0)

![](https://img.shields.io/badge/aarch64-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/aarch64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/aarch64-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/aarch64-addon-motion-video0)

![](https://img.shields.io/badge/armv7-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/armv7-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/armv7-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/armv7-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/armv7-addon-motion-video0)

![](https://img.shields.io/badge/armhf-yes-green.svg)[![](https://images.microbadger.com/badges/image/dcmartin/armhf-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armhf-addon-motion-video0)[![](https://images.microbadger.com/badges/version/dcmartin/armhf-addon-motion-video0.svg)](https://microbadger.com/images/dcmartin/armhf-addon-motion-video0)[![](https://img.shields.io/docker/pulls/dcmartin/armhf-addon-motion-video0.svg)](https://hub.docker.com/r/dcmartin/armhf-addon-motion-video0)

## Example YAML for [_add-on_](http://github.com/dcmartin/hassio-addons/tree/master/motion/CONFIGURATION.md)

+ `mqtt.host` - if using a single MQTT broker on a LAN, utilize the TCP/IPv4 addresss, e.g. `192.168.1.40`.
+ `device` - identifier for the computer, excluding reserved characters and `+`,`#`,`-`
+ `client` - limits topic subscriptions to one or all (n.b. `+`) devices
+ `cameras[].name` - identifier for the camera; must be unique for device; should be unique for group
+ `cameras[].type` - may be `local` in addition to `netcam`, `ftp`, `mqtt`
+ `cameras[].framerate` - number of frames per second to capture/attempt
+ `cameras[].threshold_percent` - pecentage of pixels changed; over-ride count with `threshold`

```
mqtt:
  host: core-mosquitto
  port: '1883'
  username: username
  password: password
group: motion
device: window
client: window
timezone: America/Los_Angeles
cameras:
  - name: window
    type: local
    framerate: 3
    threshold_percent: 1
```

## Example JSON for [`webcams.json`](http://github.com/dcmartin/motion/tree/master/motion/webcams.json.tmpl)


+ `name` - identifier for the camera, excluding reserved characters and `+`,`#`,`-`
+ `icon` - select from [Material Design Icons](http://materialdesignicons.com/)
+ `mjpeg_url` - address of live MJPEG stream; local access only by default

```
[
  {
    "name": "window",
    "icon": "xbox",
    "mjpeg_url": "http://127.0.0.1:8090/1",
    "username": "!secret motioncam-username",
    "password": "!secret motioncam-password"
  }
]
```

## Sample UX

[![motion sample](motion-video0-sample.png?raw=true "SAMPLE")](http://github.com/dcmartin/hassio-addons/tree/master/motion-video0/motion-video0-sample.png)

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

