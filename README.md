# [Home Assistant][homeassistantio] Add-ons

# 1. [Status](STATUS.md)

![](https://img.shields.io/github/license/dcmartin/hassio-addons.svg?style=flat)
![](https://img.shields.io/github/release/dcmartin/hassio-addons.svg?style=flat)
[![Build Status](https://travis-ci.org/dcmartin/hassio-addons.svg?branch=master)](https://travis-ci.org/dcmartin/hassio-addons)
[![Coverage Status](https://coveralls.io/repos/github/dcmartin/hassio-addons/badge.svg?branch=master)](https://coveralls.io/github/dcmartin/hassio-addons?branch=master)

![](https://img.shields.io/github/repo-size/dcmartin/hassio-addons.svg?style=flat)
![](https://img.shields.io/github/last-commit/dcmartin/hassio-addons.svg?style=flat)
![](https://img.shields.io/github/commit-activity/w/dcmartin/hassio-addons.svg?style=flat)
![](https://img.shields.io/github/contributors/dcmartin/hassio-addons.svg?style=flat)
![](https://img.shields.io/github/issues/dcmartin/hassio-addons.svg?style=flat)
![](https://img.shields.io/github/tag/dcmartin/hassio-addons.svg?style=flat)

![Supports amd64 Architecture][amd64-shield]
![Supports aarch64 Architecture][arm64-shield]
![Supports armhf Architecture][arm-shield]

[arm64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[arm-shield]: https://img.shields.io/badge/armhf-yes-green.svg

## About

This is a repository of add-ons for Home Assistant. You can install Home Assistant on anything (Mac, LINUX, RaspberryPi, ..).
You can read detailed Installation [instructions][hassio-install] or try the following command in a LINUX virtual machine.
```
wget -qO - ibm.biz/hassio-setup | sudo bash
```

### [Open Horizon][openhorizon-git] Examples

These addons are demonstrations of the IBM Edge Fabric, a distributed, decentralized, zero ops, edge fabric, currently in alpha, which is based on Open Horizon.

1. [`cpu2msghub`][cpu-addon] - Shared CPU addon to run [CPU2MSGHUB][cpu-pattern]
1. [`sdr2msghub`][sdr-addon] - Shared SDR (software defined radio) addon to run the [SDR2MSGHUB][sdr-pattern]
1. [`horizon`][horizon-addon] - Horizon control addon for fleets of devices.

### Home Hacking

1. `motion` - Packaging of the popular [Motion][motion-url] software for attached cameras (and network too)
1. `ageathome` - an [eldercare][ageathome] monitoring to analyze daily activities
1. `intu` - a cognitive platform using IBM Watson and the OSS [Intu][intu-url] software
1. `horizon` - an [OSS] [openhorizon-git] decentralized, zero-ops, computing platform (base)
1. `tfod` - TensorFlow On-Demand

## Installation

The installation of any add-on is pretty straightforward and not different in
comparison to installing an "app" on your smartphone.

1. Add this [repository][thisrepo] to your Hass.io _ADD-ON STORE_: 
1. Install the add-on 
1. Configure the add-on 
1. Start the add-on
1. Check the logs of the add-on to information
1. Click on the `WebUI` link to access the addon UX (iff exists)

**NOTE**: Please see the README for each add-on

## Changelog & Releases

Releases are based on [Semantic Versioning][semver], and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Support

Got questions?  Check for dcmartin on Discord (see below)

- The Home Assistant [Community Forum][forum], we have a
  [dedicated topic][forum] on that forum regarding this repository.
- The Home Assistant [Discord Chat Server][discord] for general Home Assistant
  discussions and questions.
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

## Contributing

This is an active open-source project. We are always open to people who want to
use the code or contribute to it.

Thank you for being involved! :heart_eyes:

## Authors & contributors

David C Martin (github@dcmartin.com)

The original setup of this repository is by [Franck Nijhof][frenck].

## License

MIT License

Copyright (c) 2017 David C Martin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[open-horizon]: https://github.com/open-horizon
[sdr-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/sdr2msghub
[cpu-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/cpu2msghub
[cpu-addon]: https://github.com/dcmartin/hassio-addons/tree/master/cpu2msghub
[sdr-addon]: https://github.com/dcmartin/hassio-addons/tree/master/sdr2msghub
[horizon-addon]: https://github.com/dcmartin/hassio-addons/tree/master/horizon

[buymeacoffee-shield]: https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-2.svg
[buymeacoffee]: https://www.buymeacoffee.com/dcmartin
[commits-shield]: https://img.shields.io/github/commit-activity/y/hassio-addons/addon-motion.svg
[commits]: https://github.com/dcmartin/hassio-addons/addon-motion/commits/master
[contributors]: https://github.com/dcmartin/hassio-addons/addon-motion/graphs/contributors
[discord-shield]: https://img.shields.io/discord/330944238910963714.svg
[discord]: https://discord.gg/c5DvZ4e
[forum-shield]: https://img.shields.io/badge/community-forum-brightgreen.svg
[forum]: https://community.home-assistant.io/t/repository-community-hass-io-add-ons/24705?u=frenck
[frenck]: https://github.com/frenck
[dcmartin]: https://github.com/dcmartin
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[license-shield]: https://img.shields.io/github/license/hassio-addons/addon-motion.svg
[maintenance-shield]: https://img.shields.io/maintenance/yes/2018.svg
[project-stage-shield]: https://img.shields.io/badge/project%20stage-production%20ready-brightgreen.svg
[reddit]: https://reddit.com/r/homeassistant
[releases-shield]: https://img.shields.io/github/release/hassio-addons/addon-motion.svg
[releases]: https://github.com/dcmartin/hassio-addons/addon-motion/releases
[repository]: https://github.com/dcmartin/hassio-addons/repository
[semver]: http://semver.org/spec/v2.0.0.html
[homeassistantio]: https://www.home-assistant.io/
[hassio-install]: https://www.home-assistant.io/hassio/installation/
[openhorizon-git]: https://github.com/open-horizon/
[ageathome]: http://age-at-home.mybluemix.net
[motion-url]: https://motion-project.github.io/ 
[intu-url]: https://github.com/watson-intu
[thisrepo]: https://github.com/dcmartin/hassio-addons
