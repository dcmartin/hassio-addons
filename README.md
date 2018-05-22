# DCMARTIN Hass.io add-ons for Home Assistant

![Project Stage][project-stage-shield]
![Maintenance][maintenance-shield]
![Awesome][awesome-shield]
[![License][license-shield]](LICENSE.md)

Hass.io allows anyone to create add-on repositories to share their add-ons for
Hass.io easily. This repository is one of those repositories, providing extra
Home Assistant add-ons for your Hass.io installation.

The primary goal of this project is to provide you (as a Hass.io /
Home Assistant user) with additional, high quality, add-ons that allow you to
take your automated home to the next level.

## Installation

Adding this add-ons repository to your Hass.io Home Assistant instance is
pretty easy. Follow [the official instructions][third-party-addons] on the
website of Home Assistant, and use the following URL:

```txt
https://github.com/dcmartin/hassio-addons
```

## Add-ons provided by this repository

### &#10003; [Age-At-Home][addon-ageathome]

![Latest Version][ageathome-version-shield]
![Supports armhf Architecture][ageathome-armhf-shield]
![Supports aarch64 Architecture][ageathome-aarch64-shield]
![Supports amd64 Architecture][ageathome-amd64-shield]
![Supports i386 Architecture][ageathome-i386-shield]
![Docker Pulls][ageathome-pulls-shield]

Age-At-Home is a eldercare cognitive assistant using
motion detection cameras using the Motion and Intu addons

[:books: Motion add-on documentation][addon-motion]
### &#10003; [Motion][addon-motion]

![Latest Version][motion-version-shield]
![Supports armhf Architecture][motion-armhf-shield]
![Supports aarch64 Architecture][motion-aarch64-shield]
![Supports amd64 Architecture][motion-amd64-shield]
![Supports i386 Architecture][motion-i386-shield]
![Docker Pulls][motion-pulls-shield]

Motion is a motion detection, image and video capture package.
to support the motion camera platform

[:books: Motion add-on documentation][addon-motion]

### &#10003; [Intu Self][addon-intu]

![Latest Version][intu-version-shield]
![Supports armhf Architecture][intu-armhf-shield]
![Supports aarch64 Architecture][intu-aarch64-shield]
![Supports amd64 Architecture][intu-amd64-shield]
![Supports i386 Architecture][intu-i386-shield]
![Docker Pulls][intu-pulls-shield]

Add embodied cognition through IBM Watson to your Home Assistant 

[:books: add-on documentation][addon-intu]

## Changelog

This add-on repository itself does not keep a change log, the individual
add-ons, however, do. The format is based on [Keep a Changelog][keepchangelog]
moreover, these add-ons adhere to [Semantic Versioning][semver].

## Support

Got questions?

You have several options to get them answered:

- The Home Assistant [Community Forums][forums], we have a 
  [dedicated topic][forums] on that forum regarding this repository.
- The Home Assistant [Discord Chat Server][discord] for general Home Assistant 
  discussions and questions.
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

You could also open an issue here on GitHub. Note, we use a separate
GitHub repository for each add-on. Please ensure you are creating the issue
on the correct GitHub repository matching the add-on.

- [Open an issue for the addon: Motion][motion-issue]
- [Open an issue for the addon: Intu - Intu Self][intu-issue]
- For a general repository issues or add-on ideas [open a issue here][issue]

## Contributing

This is an active open-source project. We are always open to people who want to
use the code or contribute to it.

We've set up a separate document for our [contribution guidelines](CONTRIBUTING.md).

Thank you for being involved! :heart_eyes:

We are also looking for maintainers!  
Please send [David Martin][dcmartin] a message when you are interested in becoming one.

## Authors & contributors

The original setup of this repository is by [Franck Nijhof][frenck].

For a full list of all authors and contributors,
check [the contributor's page][contributors].

## License

MIT License

Copyright (c) 2017 Franck Nijhof

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

[issue]: https://github.com/hassio-addons/repository/issues
[addon-motion]: https://github.com/hassio-addons/addon-motion
[addon-intu]: https://github.com/hassio-addons/addon-intu
[awesome-shield]: https://img.shields.io/badge/awesome%3F-yes-brightgreen.svg
[contributors]: https://github.com/hassio-addons/repository/graphs/contributors
[discord]: https://discord.gg/c5DvZ4e
[forums]: https://community.home-assistant.io/t/repository-community-hass-io-add-ons/24705?u=frenck
[frenck]: https://community.home-assistant.io/u/frenck/summary
[motion-aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[motion-amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[motion-armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[motion-i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
[motion-issue]: https://github.com/hassio-addons/addon-motion/issues
[motion-pulls-shield]: https://img.shields.io/docker/pulls/hassioaddons/motion-armhf.svg
[motion-version-shield]: https://images.microbadger.com/badges/version/hassioaddons/motion-armhf.svg
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[license-shield]: https://img.shields.io/github/license/hassio-addons/repository.svg
[maintenance-shield]: https://img.shields.io/maintenance/yes/2017.svg
[project-stage-shield]: https://img.shields.io/badge/Project%20Stage-Development-yellowgreen.svg
[reddit]: https://reddit.com/r/homeassistant
[semver]: http://semver.org/spec/v2.0.0.html
[intu-aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[intu-amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[intu-armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[intu-i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
[intu-issue]: https://github.com/hassio-addons/addon-intu/issues
[intu-pulls-shield]: https://img.shields.io/docker/pulls/hassioaddons/intu-armhf.svg
[intu-version-shield]: https://images.microbadger.com/badges/version/hassioaddons/intu-armhf.svg
[third-party-addons]: https://home-assistant.io/hassio/installing_third_party_addons/
