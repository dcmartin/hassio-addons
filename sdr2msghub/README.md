## About

This add-on is for the SDR2MSGHUB [pattern][sdr-pattern]

This add-on may require the installation of [Open Horizon][open-horizon], a distibuted, decentralized, zero-ops, method and apparatus to deploy containers.

This addon is designed to produce and consume messages containing audio fragments and GPS coordinates (latitude, longitude) from software-defined-radios (SDR) attached to participating nodes.  Messages received are processed using IBM Watson Speech-to-Text (STT) and Natural Language Understanding (NLU) to produce a JSON payload sent to a MQTT broker, e.g. `core-mosquitto` from the HASSIO addons catalog.

Detailed [documentation][edge-fabric] for the IBM Edge Fabric is available on-line.  A Slack [channel][edge-slack] is also available.

The add-on listens to Kafka messages from an IBM Message Hub operating in the IBM Cloud; messages received include an ASCII representation of a MP3 audio sequence captured from the SDR listening to local FM radio stations.

By default the system will only listen for messages, process using STT and NLU, and publish results using MQTT to the local `core-mosquitto` broker on port 1883 with topic `kafka/sdr-audio` (`username` and `password` are also supported).

If the addon is configured with SDR and Open Horizon is installed, the options for `device` and `token` will default to hostname with MAC address appended and exchange password.

**Note**: _You will need an IBM Cloud [account][ibm-registration]_

## Installation

### Install Open Horizon (OPTIONAL)

To install on Ubuntu and most Debian LINUX systems, a [script][hzn-setup] run as root from the command line will install the appropriate packages on your LINUX machine or VM:

`wget - ibm.biz/horizon-setup | bash`

More detailed instructions are [available][edge-install].  Installation package for macOS is also [available][macos-install]

### Install addon

1. [Add our Hass.io add-ons repository][repository] to your Hass.io instance.
1. Install the "sdr2msghub" add-on
1. Setup the "sdr2msghub" add-on
1. Configure `kafka` for [IBM MessageHub][kafka-creds]
1. Configure `watson_stt` to your IBM Cloud Watson Speech-to-Text [service][watson-stt]
1. Configure `watson_nlu` to your IBM Cloud Watson Natural Language Understanding [service][watson-nlu]
1. Optionally change `horizon` to Open Horizon exchange credentials; `device` and `token` default to: `hostname`-MAC and exchange password.
1. Optionally change `mqtt` if not using `host: core-mosquitto` on `port: 1883` with topic `kafka/sdr-audio` 
1. Start the "sdr2msghub" add-on
1. Check the logs of the add-on for failures :-(

## Configuration

### Option: `horizon`
Credentials required for interacting with the Open Horizon exchange; currently the only organization defined is cgiroua@us.ibm.com.  These options are ignored if Open Horizon is not installed or if `listen` option is set to `only`

The `device` and `token` values are optional and will default to the hostname with MAC address appended and the exchange password.

**Note**: _Obtain credentials and URL for the Open Horizon exchange from cgiroua@us.ibm.com_

```
  "horizon": {
    "exchange": "<url>",
    "username": "<username>",
    "password": "<password>",
    "organization": "<organization>",
    "device": "",
    "token": ""
  }
```

### Option: `kafka`

**Note**: _You must obtain [credentials][kafka-creds] for IBM MessageHub for alpha phase_

```
  "kafka": {
    "instance_id": "<instance_id>",
    "mqlight_lookup_url": "<url>",
    "api_key": "<apikey>",
    "kafka_admin_url": "<url>",
    "kafka_rest_url": "<url>",
    "kafka_brokers_sasl": [
      "<url>",
      "<url>",
      ...
    ],
    "user": "<username>",
    "password": "<password>"
  }
```

### Option: `watson_stt`

This option provides the information required to use the Watson STT service.

```
  "watson_stt": {
    "url": "https://stream.watsonplatform.net/speech-to-text/api/v1/recognize",
    "apikey": "<apikey>"
  }
```

### Option: `watson_nlu`

This option provides the information required to use the Watson NLU service.

```
  "watson_nlu": {
    "url": "https://gateway.watsonplatform.net/natural-language-understanding/api/v1/analyze?version=2018-03-19",
    "apikey": "<apikey>"
  }
```

### Option: `mqtt`

This option provides the information required for MQTT service.

```
  "mqtt": {
    "host": "core-mosquitto",
    "port": 1883,
    "topic": "kafka/sdr-audio"
    "username": "",
    "password": ""
  }
```

### Option: `listen`

Listen mode; (`true`|`false`|`only`); `false` will not listen; `only` will not attempt to register pattern.

### Option: `mock`

Process simulated (aka mock) SDR transmissions, indicated by `frequency` of zero.  Boolean; default false.

## USE

Listen to the MQTT host and port to receive JSON payload of the processed SDR audio.

1. `kafka/sdr-audio`

Configuration examples are provided for processing the JSON:

1. Edit your HomeAssistant configuration YAML to include [sdr2msghub][sdr-yaml]
1. Edit your `ui-lovelace.yaml` configuration for [display][sdr-lovelace]

## Changelog & Releases

Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors

David C Martin (github@dcmartin.com)

[commits]: https://github.com/dcmartin/hassio-addons/sdr2msghub/commits/master
[contributors]: https://github.com/dcmartin/hassio-addons/sdr2msghub/graphs/contributors
[dcmartin]: https://github.com/dcmartin
[issue]: https://github.com/dcmartin/hassio-addons/sdr2msghub/issues
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[releases]: https://github.com/dcmartin/hassio-addons/sdr2msghub/releases
[repository]: https://github.com/dcmartin/hassio-addons

[watson-nlu]: https://console.bluemix.net/catalog/services/natural-language-understanding
[watson-stt]: https://console.bluemix.net/catalog/services/speech-to-text
[edge-slack]: https://ibm-appsci.slack.com/messages/edge-fabric-users/
[ibm-registration]: https://console.bluemix.net/registration/
[kafka-creds]: https://console.bluemix.net/services/messagehub/b5f8df99-d3f6-47b8-b1dc-12806d63ae61/?paneId=credentials&new=true&env_id=ibm:yp:us-south&org=51aea963-6924-4a71-81d5-5f8c313328bd&space=f965a097-fcb8-4768-953e-5e86ea2d66b4
[sdr-yaml]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/sdr2msghub/sdr2msghub.yaml
[sdr-lovelace]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/sdr2msghub/ui-lovelace.yaml
[open-horizon]: https://github.com/open-horizon
[sdr-pattern]: https://github.com/open-horizon/examples/tree/master/edge/msghub/sdr2msghub
[edge-fabric]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/getting-started.html
[edge-install]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/adding-devices.html
[macos-install]: https://github.com/open-horizon/anax/releases
[hzn-setup]: https://raw.githubusercontent.com/dcmartin/hassio-addons/master/horizon/hzn-setup.sh
