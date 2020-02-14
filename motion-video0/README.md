# `motion-video0` - [`motion`](../motion/README.md) for `/dev/video0`

This add-on is a specialized from the [`motion`](http://github.com/dcmartin/hassio-addons/tree/master/motion/README.md) addon, **requiring** a camera at `/dev/video0`; it supports all [configuration](../motion/CONFIGURATION.md) options.

## Support architectures

![Supports amd64 Architecture][amd64-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports armhf Architecture][armhf-shield]
![Supports aarch64 Architecture][aarch64-shield]

[docker-motion-amd64]: https://hub.docker.com/r/dcmartin/amd64-addon-motion
[pulls-motion-amd64]: https://img.shields.io/docker/pulls/dcmartin/amd64-addon-motion.svg
[docker-motion-armv7]: https://hub.docker.com/r/dcmartin/armv7-addon-motion
[pulls-motion-armv7]: https://img.shields.io/docker/pulls/dcmartin/armv7-addon-motion.svg
[docker-motion-aarch64]: https://hub.docker.com/r/dcmartin/aarch64-addon-motion
[pulls-motion-aarch64]: https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-motion.svg

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg

## Example YAML

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

## Sample UX

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

[commits]: https://github.com/dcmartin/hassio-addons/motion/commits/master
[contributors]: https://github.com/dcmartin/hassio-addons/motion/graphs/contributors
[dcmartin]: https://github.com/dcmartin
[issue]: https://github.com/dcmartin/hassio-addons/motion/issues
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[releases]: https://github.com/dcmartin/hassio-addons/motion/releases
[repository]: https://github.com/dcmartin/hassio-addons

