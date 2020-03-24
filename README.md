# `hassio-addons` -  by _[**dcmartin**](http://www.dcmartin.com)_

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
![Supports armv7 Architecture][armv7-shield]
![Supports armhf Architecture][armhf-shield]

[arm64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg

## [About](STATUS.md)

This is a repository of add-ons for [Home Assistant](http://home-assistant.io)  by [**dcmartin**](http://www.dcmartin.com)

## Installation

The installation of any add-on is pretty straightforward and not different in
comparison to installing an "app" on your smartphone.

1. Add this [repository][thisrepo] to your Hass.io _ADD-ON STORE_: 
1. Install the add-on 
1. Configure the add-on 
1. Start the add-on
1. Check the logs of the add-on to information
1. Click on the `WebUI` link to access the addon UX (iff exists)

## &#128249; [`motion`](motion/README.md) _addon_
The `motion` addon provides capabilities of the [Motion Project](https://motion-project.github.io/ ) for `RTSP`, `HTTP` network cameras as well as`FTP` connected cameras.

&#9995; An attached camera (e.g. USB, Pi2, ..) may be utilized with `V4L2` (video for LINUX version 2); however, the [`motion-vi`](motion-vi/README.md) version must be utilized (n.b. it supports all other features of this _addon_).

## Authors & contributors

David C Martin (github@dcmartin.com)

Copyright (c) 2017 David C Martin

[open-horizon]: https://github.com/open-horizon

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
[motion-url]: https://motion-project.github.io/ 
[intu-url]: https://github.com/watson-intu
[thisrepo]: https://github.com/dcmartin/hassio-addons


## Stargazers
[![Stargazers over time](https://starchart.cc/dcmartin/hassio-addons.svg)](https://starchart.cc/dcmartin/hassio-addons)

## `CLOC`

Language|files|blank|comment|code
:-------|-------:|-------:|-------:|-------:
YAML|21|189|230|6980
Bourne Shell|34|672|782|3589
JSON|19|0|0|2088
C Shell|15|306|305|1870
Markdown|13|343|0|1191
HTML|6|310|573|1184
Dockerfile|14|192|98|584
Bourne Again Shell|4|54|48|288
make|1|76|52|228
CSS|1|23|7|96
--------|--------|--------|--------|--------
SUM:|128|2165|2095|18098

<img width="1" src="http://clustrmaps.com/map_v2.png?cl=ffffff&w=a&t=n&d=MGNTPfdkYUaSdwXJj5HFmzg3KsAw_tCLGy3a0Hk9E-Q"/>
