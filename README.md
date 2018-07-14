# DCMARTIN Hass.io Add-ons

[![GitHub Release][releases-shield]][releases]
![Project Stage][project-stage-shield]
[![License][license-shield]](LICENSE.md)

[![GitLab CI][gitlabci-shield]][gitlabci]
![Project Maintenance][maintenance-shield]
[![GitHub Activity][commits-shield]][commits]

[![Bountysource][bountysource-shield]][bountysource]
[![Discord][discord-shield]][discord]
[![Community Forum][forum-shield]][forum]

[![Buy me a coffee][buymeacoffee-shield]][buymeacoffee]

## About

This is a repository of add-ons for Hass.io, which is part of HomeAssistant (http://home-assistant.io)

1. motion - a packaging of the popular Motion software: https://motion-project.github.io/
1. ageathome - an applicaiton of motion used to analyze daily activities http://age-at-home.mybluemix.net
1. intu - a cognitive platform add-on https://github.com/watson-intu
1. horizon - a decentralized, zero-ops, computing platform https://github.com/open-horizon

## Installation

There are several add-ons in this repository.

The installation of any add-on is pretty straightforward and not different in
comparison to installing an "app" on your smartphone.

1. [Add this Hass.io add-ons repository][repository] to your Hass.io instance.
1. Install the add-on 
1. Configure the add-on 
1. Start the add-on
1. Check the logs of the "Example" add-on to see it in action.

**NOTE**: Please see the README for each add-on

## Changelog & Releases

This repository keeps a change log using [GitHub's releases][releases]
functionality. The format of the log is based on
[Keep a Changelog][keepchangelog].

Releases are based on [Semantic Versioning][semver], and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Support

Got questions?

You have several options to get them answered:

- The Home Assistant [Community Forum][forum], we have a
  [dedicated topic][forum] on that forum regarding this repository.
- The Home Assistant [Discord Chat Server][discord] for general Home Assistant
  discussions and questions.
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

You could also [open an issue here][issue] GitHub.

## Contributing

This is an active open-source project. We are always open to people who want to
use the code or contribute to it.

We have set up a separate document containing our
[contribution guidelines](CONTRIBUTING.md).

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

[aarch64-anchore-shield]: https://anchore.io/service/badges/image/8f74a497abc908834244d697a67675ecd13080199270598283c8e0cea1b1723e
[aarch64-anchore]: https://anchore.io/image/dockerhub/hassioaddons%2Fexample-aarch64%3Alatest
[aarch64-arch-shield]: https://img.shields.io/badge/architecture-aarch64-blue.svg
[aarch64-dockerhub]: https://hub.docker.com/r/hassioaddons/example-aarch64
[aarch64-layers-shield]: https://images.microbadger.com/badges/image/hassioaddons/example-aarch64.svg
[aarch64-microbadger]: https://microbadger.com/images/hassioaddons/example-aarch64
[aarch64-pulls-shield]: https://img.shields.io/docker/pulls/hassioaddons/example-aarch64.svg
[aarch64-version-shield]: https://images.microbadger.com/badges/version/hassioaddons/example-aarch64.svg
[amd64-anchore-shield]: https://anchore.io/service/badges/image/e8858057accd3b85042797097e3ea5b1d80010019bb22a3de32bad5219405319
[amd64-anchore]: https://anchore.io/image/dockerhub/hassioaddons%2Fexample-amd64%3Alatest
[amd64-arch-shield]: https://img.shields.io/badge/architecture-amd64-blue.svg
[amd64-dockerhub]: https://hub.docker.com/r/hassioaddons/example-amd64
[amd64-layers-shield]: https://images.microbadger.com/badges/image/hassioaddons/example-amd64.svg
[amd64-microbadger]: https://microbadger.com/images/hassioaddons/example-amd64
[amd64-pulls-shield]: https://img.shields.io/docker/pulls/hassioaddons/example-amd64.svg
[amd64-version-shield]: https://images.microbadger.com/badges/version/hassioaddons/example-amd64.svg
[armhf-anchore-shield]: https://anchore.io/service/badges/image/a86761f8fb7f0b8e0230dd1c51d01ab2acf97e553fbff0149238853fff9f5d3f
[armhf-anchore]: https://anchore.io/image/dockerhub/hassioaddons%2Fexample-armhf%3Alatest
[armhf-arch-shield]: https://img.shields.io/badge/architecture-armhf-blue.svg
[armhf-dockerhub]: https://hub.docker.com/r/hassioaddons/example-armhf
[armhf-layers-shield]: https://images.microbadger.com/badges/image/hassioaddons/example-armhf.svg
[armhf-microbadger]: https://microbadger.com/images/hassioaddons/example-armhf
[armhf-pulls-shield]: https://img.shields.io/docker/pulls/hassioaddons/example-armhf.svg
[armhf-version-shield]: https://images.microbadger.com/badges/version/hassioaddons/example-armhf.svg
[bountysource-shield]: https://img.shields.io/bountysource/team/hassio-addons/activity.svg
[bountysource]: https://www.bountysource.com/teams/hassio-addons/issues
[buymeacoffee-shield]: https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-2.svg
[buymeacoffee]: https://www.buymeacoffee.com/frenck
[commits-shield]: https://img.shields.io/github/commit-activity/y/hassio-addons/addon-example.svg
[commits]: https://github.com/hassio-addons/addon-example/commits/master
[contributors]: https://github.com/hassio-addons/addon-example/graphs/contributors
[discord-shield]: https://img.shields.io/discord/330944238910963714.svg
[discord]: https://discord.gg/c5DvZ4e
[forum-shield]: https://img.shields.io/badge/community-forum-brightgreen.svg
[forum]: https://community.home-assistant.io/t/repository-community-hass-io-add-ons/24705?u=frenck
[frenck]: https://github.com/frenck
[gitlabci-shield]: https://gitlab.com/hassio-addons/addon-example/badges/master/pipeline.svg
[gitlabci]: https://gitlab.com/hassio-addons/addon-example/pipelines
[i386-anchore-shield]: https://anchore.io/service/badges/image/d2cf5186954b12ccd3d31dcc785b36dfc8306ad850b0b29c3ceea4e466b7123a
[i386-anchore]: https://anchore.io/image/dockerhub/hassioaddons%2Fexample-i386%3Alatest
[i386-arch-shield]: https://img.shields.io/badge/architecture-i386-blue.svg
[i386-dockerhub]: https://hub.docker.com/r/hassioaddons/example-i386
[i386-layers-shield]: https://images.microbadger.com/badges/image/hassioaddons/example-i386.svg
[i386-microbadger]: https://microbadger.com/images/hassioaddons/example-i386
[i386-pulls-shield]: https://img.shields.io/docker/pulls/hassioaddons/example-i386.svg
[i386-version-shield]: https://images.microbadger.com/badges/version/hassioaddons/example-i386.svg
[issue]: https://github.com/hassio-addons/addon-example/issues
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[license-shield]: https://img.shields.io/github/license/hassio-addons/addon-example.svg
[maintenance-shield]: https://img.shields.io/maintenance/yes/2018.svg
[project-stage-shield]: https://img.shields.io/badge/project%20stage-production%20ready-brightgreen.svg
[reddit]: https://reddit.com/r/homeassistant
[releases-shield]: https://img.shields.io/github/release/hassio-addons/addon-example.svg
[releases]: https://github.com/hassio-addons/addon-example/releases
[repository]: https://github.com/hassio-addons/repository
[semver]: http://semver.org/spec/v2.0.0.html
