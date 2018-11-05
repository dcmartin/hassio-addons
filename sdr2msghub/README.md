## About

This add-on is for the [SDR pattern][sdr-pattern]

This add-on may require the installation of [OpenHorizon][open-horizon], a distibuted, decentralized, zero-ops, method and apparatus
to deploy containers.  This addon is designed to produce and consume messages containing audio fragments and GPS coordinates (latitude, longitude) 
from software-defined-radios (SDR) attached to participating nodes.  

Detailed [documentation][edge-fabric] is available.  A Slack [channel][edge-slack] is also available.

You will need an IBM Cloud [account][ibm-registration].  Once you have an IBM Cloud account, proceed to the next step.

## Installation

### Install OpenHorizon (OPTIONAL)

**Note**: _You must obtain credentials and URL for the OpenHorizon exchange from cgiroua@us.ibm.com_

**Note**: _You must obtain credentials for IBM MessageHub for [alpha phase][kafka-creds]_

If you have SDR USB device, and a LINUX host, you may install OpenHorizon by running the following (as root)

`wget - ibm.biz/horizon-setup | bash`

### Install sdr2msghub addon

1. [Add our Hass.io add-ons repository][repository] to your Hass.io instance.
1. Install the "sdr2msghub" add-on
1. Setup the "sdr2msghub" add-on
2. Optionally change `horizon` to OpenHorizon exchange credentials; `device` and `token` default to: `hostname`-MAC and exchange password.
2. Optionally change `mqtt` if not using `host: core-mosquitto` on `port: 1883` with topic `kafka/sdr-audio` (`username` and `password` are also supported)
2. Configure `kafka` to IBM MessageHub [credentials][kafka-creds]
2. Configure `watson_stt` to your IBM Cloud Watson Speech-to-Text [service][watson-stt]
2. Configure `watson_nlu` to your IBM Cloud Watson Natural Language Understanding [service][watson-nlu]
1. Start the "sdr2msghub" add-on
1. Check the logs of the add-on for failures :-(
1. Edit your HomeAssistant configuration YAML to include sdr2msghub [configuration][sdr-yaml]
1. Edit your `ui-lovelace.yaml` configuration display sdr2msghub [configuration][sdr-lovelace]

#### USE

Listen to the host and port for receiving MQTT messages.

1. `kafka/sdr-audio` -- JSON payload of SDR detected

### CONFIGURATION

### Options

#### Option: `kafka`

#### Option: `watson_stt`

#### Option: `watson_nlu`

#### Option: `horizon`

#### Option: `listen`

### Additional Options: SDR

The SDR package has extensive [documentation][SDRdoc] on available parameters.

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
[sdr-pattern]: https://github.com/open-horizon/examples/wiki/service-sdr2msghub
[edge-fabric]: https://console.test.cloud.ibm.com/docs/services/edge-fabric/getting-started.html
