# ros-humble-ros1-bridge-mavros-builder
Create a "*ros-humble-ros1-bridge*" package with support for `mavros_msgs` that can be used directly within Ubuntu 22.02 (Jammy) ROS2 Humble. Both amd64 and arm64 architectures are supported.

## How to create this builder docker images:

``` bash
  git clone https://github.com/nikhilhenry/ros-humble-ros1-bridge-mavros-builder.git
  cd ros-humble-ros1-bridge-mavros-builder

  # By default, ros-tutorals support will be built: (bridging the ros-humble-example-interfaces package)
  docker build . -t ros-humble-ros1-bridge-mavros-builder --network host
```

To build without support for ros-tutorials
``` bash
  docker build . --build-arg ADD_ros_tutorials=0 -t ros-humble-ros1-bridge-builder
```
- Note: Don't forget to install the necessary `ros-humble-mavros` packages on your ROS2 Humble in the environment you intend to run the bridge on.

## How to create ros-humble-ros1-bridge package:
###  0.) Start from the latest Ubuntu 22.04 (Jammy) ROS 2 Humble Desktop system, create the "ros-humble-ros1-bridge/" ROS2 package:

``` bash
    cd ~/
    apt update; apt upgrade
    apt -y install ros-humble-desktop
    docker run --network host --rm ros-humble-ros1-bridge-builder | tar xvzf -
```

- Note1: It's **important** that you have **`ros-humble-desktop`** installed on your ROS2 Humble system because we want to **match it with the builder image as closely as possible**.  So, if you haven't done so already, do:
``` bash
    apt -y install ros-humble-desktop
```
Otherwise you may get an error about missing `ibexample_interfaces__rosidl_typesupport_cpp.so`.  See issue https://github.com/TommyChangUMD/ros-humble-ros1-bridge-builder/issues/10


- Note1: There is no compilation at this point, the `docker run` command simply spits out a pre-compiled tarball for either amd64 or arm64 architecture, depending on the architecture of the machine you used to created the builder image.

- Note2: The assumption is that this tarball contains configurations and libraries matching your ROS2 Humble system very closely, although not identical.

## How to use ros-humble-ros1-bridge:

The package can be used by sourcing the workspace as an underlay in the ROS2 system.

```bash
source ros-humble-ros1-bridge/install/local_setup.bash
```

To test the package, an instance running ROS1 and another running ROS2 will have to communicate with each other. This can be done either on the same OS through [RoboStack](https://robostack.github.io/) or two different Docker containers.

The following instructions demonstrate how to test the package using [rocker](https://github.com/osrf/rocker).

```bash
rocker --x11 --user --privileged --persist-image \
     --volume /dev/shm /dev/shm --network=host -- ros:noetic-ros-base-focal \
     'bash -c "sudo apt update; sudo apt install -y ros-noetic-rospy-tutorials tilix; tilix"'
```

Tha docker image used above, `ros:noetic-ros-base-focal`, is multi-platform.  It runs on amd64 (eg., Intel and AMD CPUs) or arm64 architecture (eg., Raspberry PI 4B and Nvidia Jetson Orin).  Docker will automatically select the correct platform variant based on the host's architecture.

You may need to install rocker first:
``` bash
  sudo apt install python3-rocker
```
- Note0: Apparently, rocker will not work with the snap version of Docker, so make sure to install **docker.io** instead of installing it from the Snap Store.
- Note1: It's important to share the host's network and the `/dev/shm/` directory with the container.
- Note2: You can add the `--home` rocker option if you want your home directory to be shared with the docker container.  Be careful though, as the host's `~/.bashrc` will be executed inside the container.
- Note3: You can also use **ROS1 Melodic**.  Just replace `ros:noetic-ros-base-focal` with `ros:melodic-ros-base-bionic` and also replace `ros-noetic-rospy-tutorials` with `ros-melodic-rospy-tutorials`.

###  2.) Then, start "roscore" inside the ROS1 Noetic docker container

``` bash
  source /opt/ros/noetic/setup.bash
  roscore
```

###  3.) Now, from the Ubuntu 22.04 (Jammy) ROS2 Humble system, start the ros1 bridge node.

``` bash
  source /opt/ros/humble/setup.bash
  source ~/ros-humble-ros1-bridge/install/local_setup.bash
  ros2 run ros1_bridge dynamic_bridge
  # or try (See Note2):
  ros2 run ros1_bridge dynamic_bridge --bridge-all-topics
```
- Note: We need to source `local_setup.bash` and NOT `setup.bash` because the bridge was compiled in a docker container that may have different underlay locations.  Besides, we don't need to source these underlays in the host system again.

- Note2: https://github.com/ros2/ros1_bridge states that: "For efficiency reasons, topics will only be bridged when matching publisher-subscriber pairs are active for a topic on either side of the bridge. As a result **using ros2 topic echo <_topic-name_>**  doesn't work but fails with an error message Could not determine the type for the passed topic if no other subscribers are present **since the dynamic bridge hasn't bridged the topic yet**. As a **workaround** the topic type can be specified explicitly **ros2 topic echo <_topic-name_> <_topic-type_>** which triggers the bridging of the topic since the echo command represents the necessary subscriber. On the ROS 1 side rostopic echo doesn't have an option to specify the topic type explicitly. Therefore it can't be used with the dynamic bridge if no other subscribers are present. As an alternative you can use the **--bridge-all-2to1-topics option** to bridge all ROS 2 topics to ROS 1 so that tools such as rostopic echo, rostopic list and rqt will see the topics even if there are no matching ROS 1 subscribers. Run ros2 run ros1_bridge dynamic_bridge -- --help for more options."
``` bash
    $ ros2 run ros1_bridge dynamic_bridge --help
    Usage:
     -h, --help: This message.
     --show-introspection: Print output of introspection of both sides of the bridge.
     --print-pairs: Print a list of the supported ROS 2 <=> ROS 1 conversion pairs.
     --bridge-all-topics: Bridge all topics in both directions, whether or not there is a matching subscriber.
     --bridge-all-1to2-topics: Bridge all ROS 1 topics to ROS 2, whether or not there is a matching subscriber.
     --bridge-all-2to1-topics: Bridge all ROS 2 topics to ROS 1, whether or not there is a matching subscriber.
```


###  3.) Back to the ROS1 Noetic docker container, run in another terminal tab:

``` bash
  source /opt/ros/noetic/setup.bash
  rosrun rospy_tutorials talker
```

###  4.) Finally, from the Ubuntu 22.04 (Jammy) ROS2 Humble system, run in another terminal tab:

``` bash
  source /opt/ros/humble/setup.bash
  ros2 run demo_nodes_cpp listener
```

## How to add custom message from ROS1 and ROS2 source code
See an step 6.3 and 7 in the Dockerfile for an example.

- Note1: Make sure the package name ends with "_msgs".
- Note2: Use the same package name for both ROS1 and ROS2.

Also see the [troubleshoot section](#checking-example-custom-message).

- ref: https://github.com/TommyChangUMD/custom_msgs.git
- ref: https://github.com/ros2/ros1_bridge/blob/master/doc/index.rst


## How to make it work with ROS1 master running on a different machine?
- Run `roscore` on the Noetic machine as usual.
- On the Humble machine, run the bridge as below (assuming the IP address of the Noetic machine is 192.168.1.208):

``` bash
  source /opt/ros/humble/setup.bash
  source ~/ros-humble-ros1-bridge/install/local_setup.bash
  ROS_MASTER_URI='http://192.168.1.208:11311' ros2 run ros1_bridge dynamic_bridge
  # Note, change "192.168.1.208" above to the IP address of your Noetic machine.
```

## Troubleshoot

### Fixing "[ERROR] Failed to contact master":

If you have Noetic and Humble running on two different machines and have
already set the ROS_MASTER_URI environment variable, you should check the
network to ensure that the Humble machine can reach the Noetic machine via
port 11311.

``` bash
$ nc -v -z 192.168.1.208 11311
# Connection to 192.168.1.208 11311 port [tcp/*] succeeded!
```

### Checking tf2 message / service:
``` bash
$ ros2 run ros1_bridge dynamic_bridge --print-pairs | grep -i tf2
  - 'tf2_msgs/msg/TF2Error' (ROS 2) <=> 'tf2_msgs/TF2Error' (ROS 1)
  - 'tf2_msgs/msg/TFMessage' (ROS 2) <=> 'tf2_msgs/TFMessage' (ROS 1)
  - 'tf2_msgs/msg/TFMessage' (ROS 2) <=> 'tf/tfMessage' (ROS 1)
  - 'tf2_msgs/srv/FrameGraph' (ROS 2) <=> 'tf2_msgs/FrameGraph' (ROS 1)
```

### Checking AddTwoInts message / service:
- By default, `--build-arg ADD_ros_tutorials=1` is implicitly added to the `docker build ...` command.
- The ROS2 Humble system must have the `ros-humble-example-interfaces` package installed.
``` bash
$ sudo apt -y install ros-humble-example-interfaces
$ ros2 run ros1_bridge dynamic_bridge --print-pairs | grep -i addtwoints
  - 'example_interfaces/srv/AddTwoInts' (ROS 2) <=> 'roscpp_tutorials/TwoInts' (ROS 1)
  - 'example_interfaces/srv/AddTwoInts' (ROS 2) <=> 'rospy_tutorials/AddTwoInts' (ROS 1)
```

### Checking mavros message / service:
- Note: The ROS2 Humble system must have the `ros-humble-mavros` package installed.
``` bash
$ sudo apt -y install ros-humble-mavros
$ ros2 run ros1_bridge dynamic_bridge --print-pairs | grep -i mavros
  - 'mavros_msgs/msg/ADSBVehicle' (ROS 2) <=> 'mavros_msgs/ADSBVehicle' (ROS 1)
  - 'mavros_msgs/msg/ActuatorControl' (ROS 2) <=> 'mavros_msgs/ActuatorControl' (ROS 1)
  - 'mavros_msgs/msg/Altitude' (ROS 2) <=> 'mavros_msgs/Altitude' (ROS 1)
  - 'mavros_msgs/msg/AttitudeTarget' (ROS 2) <=> 'mavros_msgs/AttitudeTarget' (ROS 1)
  - 'mavros_msgs/msg/CamIMUStamp' (ROS 2) <=> 'mavros_msgs/CamIMUStamp' (ROS 1)
  - 'mavros_msgs/msg/CameraImageCaptured' (ROS 2) <=> 'mavros_msgs/CameraImageCaptured' (ROS 1)
```
## References
- https://github.com/ros2/ros1_bridge
- https://github.com/ros2/ros1_bridge/blob/master/doc/index.rst
- https://github.com/smith-doug/ros1_bridge/tree/action_bridge_humble
- https://github.com/mjforan/ros-humble-ros1-bridge
- https://packages.ubuntu.com/jammy/ros-desktop-dev
