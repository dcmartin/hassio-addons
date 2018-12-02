# Horizon Control Addon

This repository contains sample scripts to automatically setup nodes for [Open Horizon][open-horizon] as provided in the IBM Cloud.  Detailed [documentation][edge-fabric] for the IBM Cloud Edge Fabric is available on-line.  A Slack [channel][edge-slack] is also available.

You may create and publish your patterns to your organization.  Refer to the [examples][examples] available on GitHub.

## Setup

Please see the Horizon setup [instructions][dcm-oh]

## About

This add-on requires the installation of [Open Horizon][open-horizon], a distibuted, decentralized, zero-ops, method and apparatus to deploy containers.

Detailed [documentation][edge-fabric] for the IBM Edge Fabric is available on-line.  A Slack [channel][edge-slack] is also available.

**Note**: _You will need an IBM Cloud [account][ibm-registration]_

## Installation

### Install Open Horizon

To install on Ubuntu and most Debian LINUX systems, a [script][hzn-setup] run as root from the command line will install the appropriate packages on your LINUX machine or VM:

`wget -qO - ibm.biz/horizon-setup | bash`

More detailed instructions are [available][edge-install].  Installation package for macOS is also [available][macos-install]

### Install addon

1. [Add our Hass.io add-ons repository][repository] to your Hass.io instance.
1. Install the "horizon" add-on
1. Setup the "horizon" add-on
1. Configure `MSGHUB_API_KEY` for [IBM MessageHub][kafka-creds]
1. Change `exchange` to Open Horizon exchange credentials; `device` and `token` default to: `hostname`-IP and exchange password.
1. Start the "horizon" add-on
1. Check the logs of the add-on for failures :-(

## Configuration

### Option: `exchange`
Credentials required for interacting with the Open Horizon exchange; currently the only organization defined is cgiroua@us.ibm.com.

The `device` and `token` values are optional and will default to the hostname with MAC address appended and the exchange password.

```
  "exchange": {
    "username": "<username>",
    "password": "<password>",
    "organization": "cgiroua@us.ibm.com",
    "url": "https://stg-edge-cluster.us-south.containers.appdomain.cloud/v1",
    "device": "",
    "token": ""
  }
```

### Option: `MSGHUB_API_KEY`

**Note**: _You must obtain [credentials][kafka-creds] for IBM MessageHub for alpha phase_

```
  "variables": [
    {
      "env": "MSGHUB_API_KEY",
      "value": ""
    }
  ]
```

## Changelog & Releases

Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors

David C Martin (github@dcmartin.com)

[commits]: https://github.com/dcmartin/hassio-addons/cpu2msghub/commits/master
[contributors]: https://github.com/dcmartin/hassio-addons/cpu2msghub/graphs/contributors
[dcmartin]: https://github.com/dcmartin
[issue]: https://github.com/dcmartin/hassio-addons/cpu2msghub/issues
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[releases]: https://github.com/dcmartin/hassio-addons/cpu2msghub/releases
[repository]: https://github.com/dcmartin/hassio-addons

[watson-nlu]: https://console.bluemix.net/catalog/services/natural-language-understanding
[watson-stt]: https://console.bluemix.net/catalog/services/speech-to-text
[edge-slack]: https://ibm-appsci.slack.com/messages/edge-fabric-users/
[ibm-registration]: https://console.bluemix.net/registration/
[sdr-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/sdr2msghub

[open-horizon]: https://github.com/open-horizon
[cpu-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/cpu2msghub
[edge-fabric]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/getting-started.html
[edge-install]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/adding-devices.html
[macos-install]: https://github.com/open-horizon/anax/releases
[hzn-setup]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/hzn-setup.sh
[template]: https://github.com/dcmartin/open-horizon/blob/master/setup/template.json
[dcm-oh]: https://github.com/dcmartin/open-horizon/tree/master/README.md
