# &#127916; `motion` configuration 
The key options for configuration of this _addon_; the _group_, _device_, and _camera_ options identify the collection of computers and associated video sources; the `MQTT` broker is **required** to receive messages from this _addon_ as well as to enable the [`motion-ai`](http://github.com/dcmartin/motion-ai) solution.

## `group`, `device`, and `client`
The _identifiers_ distinguish collections as well as individuals; camera identifiers _must_ be unique across the group.

+ `group` - identifier for collection of devices; default: `motion`
+ `device` - identifier for the computer; default: _none_
+ `client` - limits topic subscriptions to one or all (n.b. `+`) devices

&#9995; **Identifiers** may **ONLY** include lower-case letters (`a-z`), numbers (`0-9`), and _underscore_ (`_`).

## `mqtt`
+ `mqtt.host` - if using a single MQTT broker on a LAN, utilize the TCP/IPv4 addresss, e.g. `192.168.1.40`.
+ `mqtt.port` - TCP/IP port number; default: `1883`
+ `mqtt.username` - credentials for access to broker; default: _none_
+ `mqtt.password` - credentials for access to broker; default: _none_

## `cameras`
+ `cameras[].name` - identifier for the camera; unique across _device_ and _group_; default: _none_
+ `cameras[].type` - `netcam`, `ftp`, `mqtt`; `local` is valid only for [device](../motion-video0/README.md) version
+ `cameras[].framerate` - number of frames per second to capture/attempt
+ `cameras[].threshold_percent` - pecentage of pixels changed; over-ride count with `threshold`

### Example
```
group: motion
device: kelispond
client: kelispond
timezone: America/Los_Angeles
mqtt:
  host: core-mosquitto
  port: '1883'
  username: username
  password: password
cameras:
  - name: kelispond
    type: local
    framerate: 3
    threshold_percent: 1
```

# Details
The following section details the attributes which may be used to configure the _addon_.

### Camera _type_: `network`
Network cameras are accessed directly by the _addon_ using one of three transports: `MJPEG`, `RTSP`, or `HTTP`; different cameras
require specific transports and associated attributes, e.g. credentials.  Examples are listed below:

#### `MJPEG`
```
  - name: shedcam
    type: netcam
    width: 640
    height: 480
    netcam_url: 'mjpeg://192.168.1.92:8090/1'
    netcam_userpass: 'username:password'
    threshold_percent: 1
```

#### `RTSP`
```
  - name: testcam
    type: netcam
    framerate: 3
    netcam_url: 'rtsp://192.168.93.3/live'
    threshold_percent: 1
    netcam_userpass: 'username:password'
    width: 1920
    height: 1080
```

#### `HTTP`
```
  - name: road
    netcam_url: 'http://192.168.1.36:8081/img/video.mjpeg'
    type: netcam
    netcam_userpass: 'username:password'
    width: 640
    height: 480
```

### Camera  _type_: `ftpd`

```
  - name: backyard
    type: ftpd
    netcam_url: 'http://192.168.1.183/img/video.mjpeg'
    icon: texture-box
    netcam_userpass: '!secret netcam-userpass'
```

# Example

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
