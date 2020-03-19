# `motion` - detect and classify network video feeds

This add-on is for the [Motion package][motionpkg] which provides an extensive set of capabilities to capture video feeds from a variety of sources, including real-time streaming protcol (`RSTP`),  web cameras (`HTTP`), and locally attached USB cameras (`V4L2`; local device access requires specialized version; see [`motion-local`](../motion-local/README.md) for more information.

## Docker containers

![Supports amd64 Architecture][amd64-shield][![](https://images.microbadger.com/badges/image/dcmartin/amd64-addon-motion.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/dcmartin/amd64-addon-motion.svg)](https://microbadger.com/images/dcmartin/amd64-addon-motion "Get your own version badge on microbadger.com")[![Docker Pulls][pulls-motion-amd64]][docker-motion-amd64]

![Supports armv7 Architecture][armv7-shield][![](https://images.microbadger.com/badges/image/dcmartin/armv7-addon-motion.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/dcmartin/armv7-addon-motion.svg)](https://microbadger.com/images/dcmartin/armv7-addon-motion "Get your own version badge on microbadger.com")[![Docker Pulls][pulls-motion-armv7]][docker-motion-armv7]

![Supports aarch64 Architecture][aarch64-shield][![](https://images.microbadger.com/badges/image/dcmartin/aarch64-addon-motion.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion "Get your own image badge on microbadger.com")[![](https://images.microbadger.com/badges/version/dcmartin/aarch64-addon-motion.svg)](https://microbadger.com/images/dcmartin/aarch64-addon-motion "Get your own version badge on microbadger.com")[![Docker Pulls][pulls-motion-aarch64]][docker-motion-aarch64]

[docker-motion-amd64]: https://hub.docker.com/r/dcmartin/amd64-addon-motion
[pulls-motion-amd64]: https://img.shields.io/docker/pulls/dcmartin/amd64-addon-motion.svg
[docker-motion-armv7]: https://hub.docker.com/r/dcmartin/armv7-addon-motion
[pulls-motion-armv7]: https://img.shields.io/docker/pulls/dcmartin/armv7-addon-motion.svg
[docker-motion-aarch64]: https://hub.docker.com/r/dcmartin/aarch64-addon-motion
[pulls-motion-aarch64]: https://img.shields.io/docker/pulls/dcmartin/aarch64-addon-motion.svg

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg

## Installation

The installation of this add-on is pretty straightforward and not different in
comparison to installing any other Hass.io add-on.

1. [Add our Hass.io add-ons repository][repository] to your Hass.io instance.
1. Install the "Motion" add-on
1. Configure the "Motion" add-on
1. Start the "Motion" add-on
1. Check the logs of the "Motion" add-on for failures :-(
1. Select the "Open WebUI" button to see the cameras output

**Note**: _Remember to SAVE and then restart the add-on when the configuration is changed._

## MQTT

Specify the host and port for sending MQTT messages.  All topics begin with the `devicedb` specified, which defaults to "motion".

+ `<devicedb>/{name}/{camera}` -- JSON payload of motion detected
+ `<devicedb>/{name}/{camera}/lost` -- JSON payload of motion detected
+  `<devicedb>/{name}/{camera}/event/start` -- JSON payload of motion detected
+ `<devicedb>/{name}/{camera}/event/end` -- JSON payload of motion detected
+ `<devicedb>/{name}/{camera}/image` -- JPEG payload of image (**see** `post_pictures`)
+ `<devicedb>/{name}/{camera}/image-average` -- JPEG payload of average event 
+ `<devicedb>/{name}/{camera}/image-blend` -- JPEG payload of blended event (50%)
+ `<devicedb>/{name}/{camera}/image-composite` --  JPEG payload of composite event
+ `<devicedb>/{name}/{camera}/image-animated` -- GIF payload of event
+ `<devicedb>/{name}/{camera}/image-animated-mask` -- GIF payload of event (as B/W mask)

## CONFIGURATION
This addon supports multiple installations across mutliple devices (e.g. RaspberryPi3 w/ USB PS3 Eye camera and LINUX PC w/ Wifi network cameras.  The options include `devicedb` specifying a shared group of devices; it is also used as MQTT discovery prefix.  The `name` identifies the logical host of the camera(s), and `www` identifies the primary web server for the group; typically this is the same as the `name` with domain appended (e.g. `.local`).  For example:

#### &#9995; Naming
A `group`, `device`, or `camera` _name_ may **ONLY** include lower-case letters (`a-z`), numbers (`0-9`), and _underscore_ (`_`).

### Option: `post_pictures`

This specifies if pictures should be posted to MQTT as they are captured (i.e. "on") _or_ if a single picture should be posted for each event.
The value may be "on" to post every picture; "off" to post no pictures; or one of the following:

1. "best" - the picture with movement closest to the center
1. "center" - the center picture (half-way between start and end of event)
1. "first" - the first picture 
1. "last" - the last picture
1. "most" - the picture with the most pixels changed from previous frame

### Option: `camera`

Options which can be specified on a per camera basis are:

1. name (string, non-optional)
1. url (string, optional; ignored if device is specified)
1. userpass (string, optional; only applicable with url; format "user:pass"; defaults to netcam_userpass)
1. keepalive (string, optional; only applicable with url; valid {"1.1","1.0","force"}; defaults to netcam_keepalive)
1. port (streaming output port, optional; will be calculated from stream_port)
1. quality \[of captured JPEG image\] (int, optional; valid \[0,100); default 80)
1. type (string, optional; valid { wcv80n, ps3eye, kinect, c920 }; default wcv80n)
1. fps (int, optional; valid \[0,100); defaults to framerate, default 5)
1. fov (int, optional; valid \[0,360); defaults from camera type iff specified)
1. width (int, optional; default 640; defaults from camera type iff specified)
1. height (int, optional; default 480; defaults from camera type iff specified)
1. rotate (int, optional; valid (0,360); default 0)
1. threshold \[of pixels changed to detect motion\] (int, optional; valid (0,10000); default 5000)
1. models \[for visual recognition\] (string, optional; format "\[wvr|digits\]:modelname,<model2>,..")

### Example

```
log_level: info
log_motion_level: error
log_motion_type: ALL
default:
  post_pictures: best
  interval: 30
  despeckle: EedDl
  changes: 'off'
  text_scale: 1
  framerate: 5
  brightness: 100
  contrast: 50
  event_gap: 10
  fov: 62
  hue: 50
  lightswitch: 0
  palette: 15
  picture_quality: 100
  stream_quality: 100
  threshold_percent: 10
  saturation: 0
  netcam_userpass: 'username:password'
  username: username
  password: password
  height: 480
  width: 640
  movie_output: 'off'
  movie_max: 15
  movie_quality: 60
mqtt:
  host: mqtt.dcmartin.com
  port: '1883'
  username: username
  password: password
group: motion
device: netcams
client: motion-local
timezone: America/Los_Angeles
cameras:
  - name: poolcam
    netcam_url: 'http://192.168.1.162/nphMotionJpeg?Resolution=640x480&Quality=Clarity'
    type: netcam
    icon: water
    netcam_userpass: 'poolcamuser:poolcampass'
  - name: interiorgate
    netcam_url: 'http://192.168.1.38:8081/img/video.mjpeg'
    type: netcam
    icon: gate
    netcam_userpass: 'interiorgateuser:interiorgatepass'
  - name: road
    netcam_url: 'http://192.168.1.36:8081/img/video.mjpeg'
    type: netcam
    icon: road
    post_pictures: center
    netcam_userpass: 'roaduser:roadpass'
  - name: dogpond
    type: netcam
    icon: car
    netcam_url: 'rtsp://192.168.1.224/live'
    framerate: 2
    threshold_percent: 2
  - name: pondview
    type: netcam
    icon: waves
    netcam_url: 'rtsp://192.168.1.225/live'
    framerate: 2
    threshold_percent: 5
  - name: shed
    type: netcam
    icon: window-shutter-open
    netcam_url: 'rtsp://192.168.1.223/live'
    framerate: 2
    threshold_percent: 1
```

### Additional Options: Motion

The Motion package has extensive [documentation][motiondoc] on available parameters.  Almost all parameters are avsailable.
The JSON configuration options are provided using the same name as in the Motion documentation.

## Sample output

![motion sample](motion-sample.png?raw=true "SAMPLE")

## Changelog & Releases

Releases are based on Semantic Versioning, and use the format
of ``MAJOR.MINOR.PATCH``. In a nutshell, the version will be incremented
based on the following:

- ``MAJOR``: Incompatible or major changes.
- ``MINOR``: Backwards-compatible new features and enhancements.
- ``PATCH``: Backwards-compatible bugfixes and package updates.

## Authors & contributors

David C Martin (github@dcmartin.com)

The original setup of this repository is by [Franck Nijhof][frenck].

[commits]: https://github.com/dcmartin/hassio-addons/motion/commits/master
[contributors]: https://github.com/dcmartin/hassio-addons/motion/graphs/contributors
[dcmartin]: https://github.com/dcmartin
[issue]: https://github.com/dcmartin/hassio-addons/motion/issues
[keepchangelog]: http://keepachangelog.com/en/1.0.0/
[releases]: https://github.com/dcmartin/hassio-addons/motion/releases
[repository]: https://github.com/dcmartin/hassio-addons
[motionpkg]: https://motion-project.github.io]
[motiondoc]: https://motion-project.github.io/motion_config.html
[watsonvr]: https://www.ibm.com/watson/services/visual-recognition
[digitsgit]: https://github.com/nvidia/digits
[digits]: https://developer.nvidia.com/digits
