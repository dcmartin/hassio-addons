# YOLO2MSGHUB addon for Home Assistant


This [Home Assistant][home-assistant] add-on is for use with
the [Open Horizon][open-horizon] pattern-service: [`yolo2msghub`](http://github.com/dcmartin/open-horizon/master/tree/yolo2msghub/README.md)

## About

This addon is designed to consume Kafka messages on the topic `yolo2msghub` and produce MQTT messages for consumption by the [`MQTT broker`][core-mosquitto] addon using the specified topic (see **Options** below).

Detailed [documentation][edge-fabric] for the IBM Edge Fabric is available on-line.  A Slack [channel][edge-slack] is also available.

## Installation

### Install addon

1. [Add this repository][repository] to your Hass.io addon store.
1. Install the "yolo2msghub" add-on
1. Setup the "yolo2msghub" add-on
  - Configure `kafka` with your Kafka API key
  - Optionally change `mqtt` for `host`, `port`, `topic`, `username`, and `password`
1. Start the "yolo2msghub" add-on
1. Check the logs of the add-on for failures :-(

## Configuration

### Option: `kafka`
Credentials required for sending and receiving messages using the IBM Cloud MessageHub.
```
  "kafka": {
    "api_key": "<Your IBM Edge Fabric MessageHub API key>",
    "brokers": "kafka03-prod02.messagehub.services.us-south.bluemix.net:9093,kafka04-prod02.messagehub.services.us-south.bluemix.net:9093,kafka01-prod02.messagehub.services.us-south.bluemix.net:9093,kafka02-prod02.messagehub.services.us-south.bluemix.net:9093,kafka05-prod02.messagehub.services.us-south.bluemix.net:9093"
  }
```

### Option: `mqtt`
This option provides the information required for MQTT service; defaults are as specified below.
```
  "mqtt": {
    "host": "core-mosquitto",
    "port": 1883,
    "topic": "kafka/cpu-load"
    "username": "",
    "password": ""
  }
```

## USE

Listen to the MQTT host and port to receive JSON payload of the processed YOLO image.

1. `kafka/yolo-image`

Configuration examples are provided for processing the JSON:

1. Edit your HomeAssistant configuration YAML to include [yolo2msghub][yolo-yaml]
1. Edit your `ui-lovelace.yaml` configuration for [display][yolo-lovelace]

# Sample output

![yolo2msghub activity](yolo2msghub_activity.png?raw=true "YOLO2MSGHUB")

## Changelog & Releases

Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors

David C Martin (github@dcmartin.com)

[yolo-lovelace]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/yolo2msghub/ui-lovelace.yaml
[yolo-yaml]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/yolo2msghub/yolo2msghub.yaml

[commits]: https://github.com/dcmartin/hassio-addons/yolo2msghub/commits/master
[contributors]: https://github.com/dcmartin/hassio-addons/yolo2msghub/graphs/contributors
[releases]: https://github.com/dcmartin/hassio-addons/yolo2msghub/releases
[issue]: https://github.com/dcmartin/hassio-addons/yolo2msghub/issues

[core-mosquitto]: https://github.com/hassio-addons/repository/tree/master/mqtt

[dcmartin]: https://github.com/dcmartin
[repository]: https://github.com/dcmartin/hassio-addons
[dcm-oh]: https://github.com/dcmartin/open-horizon
[dcm-oh-setup]: https://github.com/dcmartin/open-horizon/tree/master/setup
[cpu-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/cpu2msghub
[yolo-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/yolo2msghub
[cpu-addon]: https://github.com/dcmartin/hassio-addons/tree/master/cpu2msghub
[yolo-addon]: https://github.com/dcmartin/hassio-addons/tree/master/yolo2msghub
[horizon-addon]: https://github.com/dcmartin/hassio-addons/tree/master/horizon

[edge-fabric]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/getting-started.html
[edge-install]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/adding-devices.html
[edge-slack]: https://ibm-appsci.slack.com/messages/edge-fabric-users/
[home-assistant]: https://home-assistant.io/
[hzn-setup]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/hzn-setup.sh
[ibm-apikeys]: https://console.bluemix.net/iam/#/apikeys
[ibm-registration]: https://console.bluemix.net/registration/
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[macos-install]: https://github.com/open-horizon/anax/releases
[open-horizon]: https://github.com/open-horizon
[repository]: https://github.com/dcmartin/hassio-addons
[watson-nlu]: https://console.bluemix.net/catalog/services/natural-language-understanding
[watson-stt]: https://console.bluemix.net/catalog/services/speech-to-text
