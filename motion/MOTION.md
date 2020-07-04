# `MOTION.md` - API for motion

The following definitions will be used when summarizing the commands that are available for control of Motion.

+ `{IP}` - The IP address of the computer running Motion
+ `{port}` The port specified for the webcontrol
+ `{camid}` The camera_id of the camera.
+ `{parm}` The Motion configuration parameter requested.
+ `{value1}` The first value of the Motion configuration parameter requested.
+ `{value2}` The second value of the Motion configuration parameter requested.

The following are the commands available.

+ `{IP}:{port}/{camid}/config/list` - Lists all the configuration values for the camera.
+ `{IP}:{port}/{camid}/config/set?{parm}={value1}` - Set the value for the requested parameter
+ `{IP}:{port}/{camid}/config/get?query={parm}` - Return the value currently set for the parameter.
+ `{IP}:{port}/{camid}/config/write` - Write the current parameters to the file.
+ `{IP}:{port}/{camid}/detection/status` - Return the current status of the camera.
+ `{IP}:{port}/{camid}/detection/connection` - Return the connection status of the camera.
+ `{IP}:{port}/{camid}/detection/start` - Start or resume motion detection.
+ `{IP}:{port}/{camid}/detection/pause` - Pause the motion detection.
+ `{IP}:{port}/{camid}/action/eventstart` - Trigger a new event.
+ `{IP}:{port}/{camid}/action/eventend` - Trigger the end of a event.
+ `{IP}:{port}/{camid}/action/snapshot` - Create a snapshot
+ `{IP}:{port}/{camid}/action/restart` - Restart Motion
+ `{IP}:{port}/{camid}/action/quit` - Close all connections to the camera
+ `{IP}:{port}/{camid}/action/end` - Shutdown the Motion application
+ `{IP}:{port}/{camid}/track/center` - Center PTZ camera
+ `{IP}:{port}/{camid}/track/set?x={value1}&y={value2}` - Move PTZ camera to location specified by x and y
+ `{IP}:{port}/{camid}/track/set?pan={value1}&tilt={value2}` - Pan PTZ camera to value1 and tilt to value2

As a general rule, when the `{camid}` references the `camera_id` in
the main motion.conf file, the webcontrol actions referenced above
are going to be applied to every camera that is connected to Motion.
This `camera_id` is usually specified as 0 (zero).  So issuing a command
of `{IP}:{port}/0/detection/pause` is going to pause all the
cameras.

A point of clarification with respect to the differences between
`pause`, `quit`, and `end`. When the action of `pause` is executed, Motion
will stop the motion detection processing and of course all events
but will continue to process and decode images from the camera.
This allows for a faster transition when the user executes a start
The `quit` action conversely not only stops the motion detection but
also disconnects from the camera and decoding of images. To start
motion detection after a `quit`, the user must execute a `restart` which
will reinitialize the connection to the camera. And since the camera
was completely disconnect, it can take more than a few seconds for
Motion to fully start and have the camera available for processing
or viewing. Finally, there is an option for `end`. This option
completely terminates the Motion application. It closes all connections
to all the cameras and terminates the application. This may be
required when running Motion in daemon mode. Note that there is no
way to restart the Motion application from the webcontrol interface
after processing a end request.

If the item above is available via the HTML/CSS interface, it is
also possible to see the exact URL sent to Motion in the log. Change
the log level to 8 (debug), then open up the Motion webcontrol
interface and perform the action in question. In the log Motion
will report the exact URL sent to Motion that performed the action.

**ALERT!** Security Warning! This feature also means you have to pay attention to the following.

Anyone with access to the remote control port (http) can alter the
values of options and save files anywhere on your server with the
same privileges as the user running Motion. They can execute any
command on your computer with the same privileges as the user running
Motion. Anyone can access your control port if you have not either
limited access to localhost or limited access using firewalls in
the server. You should always have a router between a machine running
Motion with remote control enabled and the Internet and make sure
the Motion control port is not accessible from the outside. Also
make sure to adjust the webcontrol_parms to the lowest level possible.

If you limit control port to localhost you still need to take care of any user logging into the server with any kind of terminal session.

Run Motion as a harmless user. DO NOT RUN AS ROOT!!
