# Horizon Control Addon

This repository contains an [Open Horizon][open-horizon] `control` addon to periodically scan the local-area-network (LAN) and automatically configured nodes identified by MAC address; currently only RaspberryPi model 3/3+ running Raspbian Stretch are supported.  More information about the initialization script is [here][dcm-oh-setup]. Detailed documentation for the IBM Cloud Edge Fabric is available [on-line][edge-fabric].  A Slack [channel][edge-slack] is also available.  Refer to the [examples][examples] available on GitHub.

**Note**: _You will need an IBM Cloud [account][ibm-registration]_

## Install Open Horizon

Please refer to the Horizon setup [instructions][dcm-oh].  More detailed instructions are [available][edge-install].  Installation package for macOS is also [available][macos-install]

# Install addon

1. [Add our Hass.io add-ons repository][repository] to your Hass.io instance.
1. Install the "horizon" add-on
1. Configure the "horizon" add-on (see below)
1. Start the "horizon" add-on
1. Check the logs of the add-on for failures :-(

## Configure addon

### Options: Home Assistant
These options are for the Home Assistant environment hosting this control addon.  These values will be specified in the modifications to the HA environment, ***which will be replaced***.
#### : `log-level`
#### : `timezone`
#### : `unit_system`
#### : `latitude`
#### : `longitude`
#### : `elevation`

### Option: `refresh`
Number of seconds between scans for new devices on the LAN and installation or update as appropriate.

### Option: `mqtt`
Server required to send and receive MQTT messages between clients and servers on the LAN.  Defaults are as below:
```
"mqtt": {
    "host": "core-mosquitto",
    "port": 1883,
    "username": "",
    "password": ""
}
```

### Option: `cloudant`
Database required to store node (`hzn-config`) and addon configuration information; the addon database is `<IBM_CLOUD_LOGIN_EMAIL>` without the `@host.tld` appended. Configurations specified in the `horizon.config` attribute (see _Option: `horizon`_) refer to record identifiers in `hzn-config`.
```
"cloudant": {
    "url": "<CLOUDANT URL>",
    "username": "CLOUDANT USERNAME>",
    "password": "<CLOUDANT PASSWORD>"
  }
```

### Option: `horizon`
Credentials required for controlling and interacting with the Open Horizon exchange.  For more information about the `horizon.config` reference specification, please refer [here][dcm-oh-setup].
```
"horizon": {
    "apikey": "<HORIZON_API_KEY>",
    "org": "<IBM_CLOUD_LOGIN_EMAIL>",
    "device": "<YOUR DEVICE NAME>",
    "url": "https://alpha.edge-fabric.com/v1",
    "config": "<CLOUDANT CONFIGURATION ID>"
}
```

## USE

Listen to the MQTT host and port to receive JSON payload of nodes.  The _CONFIGURATION_ identifier is from the `horizon.config` option; the _DEVICE_ identifier is from the node specified in that configuration (e.g. `test-cpu-1`).

1. `<CONFIGURATION>/<DEVICE>/start`

A complete configuration is automatically generated from templates modified based on _Options_ specified (per above).

1. [configuration.yaml][horizon-yaml]
1. [groups.yaml][horizon-groups]
1. [automations.yaml][horizon-automations]
1. [secrets.yaml][horizon-secrets]
1. [ui-lovelace.yaml][horizon-lovelace]

# Sample output

![horizon sample](horizon-sample.png?raw=true "HORIZON")

## Changelog & Releases

Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors

David C Martin (github@dcmartin.com)

[horizon-lovelace]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/rootfs/var/config/ui-lovelace.yaml
[horizon-yaml]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/rootfs/var/config/configuration.yaml
[horizon-groups]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/rootfs/var/config/groups.yaml
[horizon-automations]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/rootfs/var/config/automations.yaml
[horizon-secrets]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/rootfs/var/config/secrets.yaml


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

[open-horizon]: https://github.com/open-horizon
[sdr-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/sdr2msghub
[cpu-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/cpu2msghub
[cpu-addon]: https://github.com/dcmartin/hassio-addons/tree/master/cpu2msghub
[sdr-addon]: https://github.com/dcmartin/hassio-addons/tree/master/sdr2msghub

[edge-fabric]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/getting-started.html
[edge-install]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/adding-devices.html
[macos-install]: https://github.com/open-horizon/anax/releases
[hzn-setup]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/hzn-setup.sh
[template]: https://github.com/dcmartin/open-horizon/blob/master/setup/template.json
[dcm-oh]: https://github.com/dcmartin/open-horizon/tree/master/README.md
[dcm-oh-setup]: https://github.com/dcmartin/open-horizon/tree/master/setup
[examples]: https://github.com/open-horizon/examples
