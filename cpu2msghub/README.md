# Open Horizon `cpu2msghub` addon for Home Assistant

This [Home Assistant][home-assistant] add-on is for the [Open Horizon][open-horizon] [`cpu2msghub`][cpu-pattern] pattern

This add-on requires the [setup][dcm-oh] of Horizon, a distibuted, decentralized, zero-ops, method and apparatus to deploy containers from the IBM Cloud.

**Note**: _You will need an IBM Cloud [account][ibm-registration]_

## About

This addon is designed to produce and consume messages containing audio fragments and GPS coordinates (latitude, longitude) from software-defined-radios (CPU) attached to participating nodes.  Messages received are processed using IBM Watson Speech-to-Text (STT) and Natural Language Understanding (NLU) to produce a JSON payload sent to a MQTT broker, e.g. `core-mosquitto` from the HASSIO addons catalog.

Detailed [documentation][edge-fabric] for the IBM Edge Fabric is available on-line.  A Slack [channel][edge-slack] is also available.

The add-on listens to Kafka messages from an IBM Message Hub operating in the IBM Cloud.

By default the system will only listen for messages and publish results using MQTT to the local `core-mosquitto` broker on port 1883 with topic `kafka/cpu-load` (`username` and `password` are also supported).

If the addon is configured with CPU and Open Horizon is installed, the options for `device` and `token` will default to hostname and exchange password.

## Installation

### Install Open Horizon (OPTIONAL)

Please refer to the [`open-horizon`][dcm-oh] repository.

### Install addon

1. [Add this repository][repository] to your Hass.io addon store.
1. Install the "cpu2msghub" add-on
1. Setup the "cpu2msghub" add-on
  - Configure `kafka` with your IBM MessageHub API key (n.b. default username is `iamapikey`)
  - Configure `horizon` with your IBM Cloud username (e.g. `dcmartin@us.ibm.com`) and [Platform API key][ibm-apikeys]

  - Optionally change `mqtt` if not using `host: core-mosquitto` on `port: 1883` with topic `kafka/cpu-load` 
1. Start the "cpu2msghub" add-on
1. Check the logs of the add-on for failures :-(

## Configuration

### Option: `horizon`
Credentials required for interacting with the Open Horizon exchange. These options are ignored if Open Horizon is not installed or if `listen` option is set to `only`

The `device` and `token` values are optional and will default to the hostname with MAC address appended and the exchange password.

**Note**: _Obtain credentials and URL for the Open Horizon exchange from cgiroua@us.ibm.com_

```
  "horizon": {
    "password": "<Your IBM Cloud Platform API key>",
    "organization": "<Your IBM Cloud login email address>",
    "username": "iamapikey",
    "exchange": "https://alpha.edge-fabric.com/v1"

  }
```

### Option: `kafka`

**Note**: _You must obtain an API key; request one in the IBM Edge Fabric [Slack][edge-slack]_

```
  "kafka": {
    "api_key": "<Your IBM Edge Fabric MessageHub API key>",
    "brokers": "kafka03-prod02.messagehub.services.us-south.bluemix.net:9093,kafka04-prod02.messagehub.services.us-south.bluemix.net:9093,kafka01-prod02.messagehub.services.us-south.bluemix.net:9093,kafka02-prod02.messagehub.services.us-south.bluemix.net:9093,kafka05-prod02.messagehub.services.us-south.bluemix.net:9093"
  }
```

### Option: `mqtt`

This option provides the information required for MQTT service.

```
  "mqtt": {
    "host": "core-mosquitto",
    "port": 1883,
    "topic": "kafka/cpu-load"
    "username": "",
    "password": ""
  }
```

### Option: `listen`

Listen mode; (`true`|`false`|`only`); `false` will not listen; `only` will not attempt to register pattern.

## USE

Listen to the MQTT host and port to receive JSON payload of the processed CPU load.

1. `kafka/cpu-load`

Configuration examples are provided for processing the JSON:

1. Edit your HomeAssistant configuration YAML to include [cpu2msghub][cpu-yaml]
1. Edit your `ui-lovelace.yaml` configuration for [display][cpu-lovelace]

# Sample output

![cpu2msghub cpu](cpu2msghub_cpu.png?raw=true "CPU2MSGHUB")

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
[home-assistant]: https://home-assistant.io/

[dcm-oh]: https://github.com/dcmartin/open-horizon

[watson-nlu]: https://console.bluemix.net/catalog/services/natural-language-understanding
[watson-stt]: https://console.bluemix.net/catalog/services/speech-to-text
[edge-slack]: https://ibm-appsci.slack.com/messages/edge-fabric-users/
[ibm-registration]: https://console.bluemix.net/registration/
[ibm-apikeys]: https://console.bluemix.net/iam/#/apikeys

[cpu-yaml]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/cpu2msghub/cpu2msghub.yaml
[cpu-lovelace]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/cpu2msghub/ui-lovelace.yaml
[open-horizon]: https://github.com/open-horizon
[cpu-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/cpu2msghub
[edge-fabric]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/getting-started.html
[edge-install]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/adding-devices.html
[macos-install]: https://github.com/open-horizon/anax/releases
[hzn-setup]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/hzn-setup.sh
