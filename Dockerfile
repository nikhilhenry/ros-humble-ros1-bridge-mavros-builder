FROM ros:humble-ros-base-jammy
# The above base image is multi-platform (works on ARM64 and AMD64):
# Make sure bash catches errors (no need to chain commands with &&, use ; instead)
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-c"]

###########################
# 1.) Bring system up to the latest ROS desktop configuration
###########################
RUN apt-get -y update;
RUN apt-get -y upgrade;
RUN apt-get -y install ros-humble-desktop;

###########################
# 2.) Temporarily remove ROS2 apt repository
###########################
RUN mv /etc/apt/sources.list.d/ros2.sources /root/;
RUN apt-get update;

###########################
# 3.) comment out the catkin conflict
###########################
RUN sed  -i -e 's|^Conflicts: catkin|#Conflicts: catkin|' /var/lib/dpkg/status;
RUN apt-get install -f;

###########################
# 4.) force install these packages
###########################
RUN apt-get download python3-catkin-pkg;
RUN apt-get download python3-rospkg;
RUN apt-get download python3-rosdistro;
RUN dpkg --force-overwrite -i python3-catkin-pkg*.deb;
RUN dpkg --force-overwrite -i python3-rospkg*.deb;
RUN dpkg --force-overwrite -i python3-rosdistro*.deb;
RUN apt-get install -f;

###########################
# 5.) Install the latest ROS1 desktop configuration
# see https://packages.ubuntu.com/jammy/ros-desktop-dev
# note: ros-desktop-dev automatically includes tf tf2
###########################
RUN apt-get -y install ros-desktop-dev;

# fix ARM64 pkgconfig path issue -- Fix provided by ambrosekwok
RUN if [[ $(uname -m) = "arm64" || $(uname -m) = "aarch64" ]]; then                     \
      cp /usr/lib/x86_64-linux-gnu/pkgconfig/* /usr/lib/aarch64-linux-gnu/pkgconfig/;   \
    fi;

###########################
# 6.) Restore the ROS2 apt repos and set compilation options.
#   For example, to include ROS tutorial message types, pass
#   "--build-arg ADD_ros_tutorials=1" to the docker build command.
###########################
RUN mv /root/ros2.sources /etc/apt/sources.list.d/;
RUN apt-get -y update;

# for ros-humble-example-interfaces:
ARG ADD_ros_tutorials=1

# sanity check:
RUN echo "ADD_ros_tutorials         = '$ADD_ros_tutorials'";

###########################
# 6.1) Add ROS1 ros_tutorials messages and services
# eg., See AddTwoInts server and client tutorial
###########################
RUN if [[ "$ADD_ros_tutorials" = "1" ]]; then                                           \
      git clone -b noetic-devel --depth=1 https://github.com/ros/ros_tutorials.git;     \
      cd ros_tutorials;                                                                 \
      unset ROS_DISTRO;                                                                 \
      time colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release;                        \
    fi;

###########################

######################################
# 6.3) Compile mavros_msgs and its dependencies(uuid_msgs and geographic_msgs)
######################################
RUN git clone https://github.com/ros-geographic-info/unique_identifier.git;             \
      #                                                                                 \
      # Compile for ROS1:                                                               \
      #                                                                                 \
      cd /unique_identifier/uuid_msgs;                                                  \
      unset ROS_DISTRO;                                                                 \
      time colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release;

RUN git clone https://github.com/ros-geographic-info/geographic_info.git;               \
      # Create copies of ROS1 and ROS2 versions                                         \
      source /unique_identifier/uuid_msgs/install/setup.bash;                           \
      mkdir /geographic_msgs;                                                           \
      cp -r /geographic_info/geographic_msgs /geographic_msgs/geographic_msgs_ros1;     \
      cd /geographic_info;                                                              \
      git checkout ros2;                                                                \
      cd / ;                                                                            \
      #                                                                                 \
      # Compile for ROS1:                                                               \
      #                                                                                 \
      cp -r /geographic_info/geographic_msgs /geographic_msgs/geographic_msgs_ros2;     \
      cd /geographic_msgs/geographic_msgs_ros1;                                         \
      unset ROS_DISTRO;                                                                 \
      time colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release;                        \
      #                                                                                 \
      # Compile for ROS2:                                                               \
      #                                                                                 \
      cd /geographic_msgs/geographic_msgs_ros2;                                         \
      source /opt/ros/humble/setup.bash;                                                \
      time colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release;

RUN git clone https://github.com/mavlink/mavros.git;                    \
      # Create copies of ROS1 and ROS2 versions                         \
      mkdir /mavros_msgs;                                               \
      # Since ROS2 is the default branch                                \
      cp -r /mavros/mavros_msgs /mavros_msgs/mavros_msgs_ros2;          \
      cd /mavros;                                                       \
      git checkout master;                                              \
      cd /;                                                             \
      cp -r /mavros/mavros_msgs /mavros_msgs/mavros_msgs_ros1;          \
      #                                                                 \
      # Compile for ROS1:                                               \
      #                                                                 \
      source /geographic_msgs/geographic_msgs_ros1/install/setup.bash;  \
      cd /mavros_msgs/mavros_msgs_ros1;                                 \
      unset ROS_DISTRO;                                                 \
      time colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release;        \
      #                                                                 \
      # Compile for ROS2:                                               \
      #                                                                 \
      source /geographic_msgs/geographic_msgs_ros2/install/setup.bash;  \
      cd /mavros_msgs/mavros_msgs_ros2;                                 \
      source /opt/ros/humble/setup.bash;                                \
      time colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release;

###########################
# 7.) Compile ros1_bridge
###########################
RUN                                                                                             \
    #-------------------------------------                                                      \
    # Apply the ROS2 underlay                                                                   \
    #-------------------------------------                                                      \
    source /opt/ros/humble/setup.bash;                                                          \
    #                                                                                           \
    #-------------------------------------                                                      \
    # Apply additional message / service overlays                                               \
    #-------------------------------------                                                      \
    if [[ "$ADD_ros_tutorials" = "1" ]]; then                                                   \
      # Apply ROS1 package overlay                                                              \
      source ros_tutorials/install/setup.bash;                                                  \
      # Apply ROS2 package overlay                                                              \
      apt-get -y install ros-humble-example-interfaces;                                         \
      source /opt/ros/humble/setup.bash;                                                        \
    fi;                                                                                         \
                                                                                                \
                                                                                                \
      # Apply ROS1 package overlay                                                              \
      source /geographic_msgs/geographic_msgs_ros1/install/setup.bash;                          \
      source /mavros_msgs/mavros_msgs_ros1/install/setup.bash;                                  \
      # Apply ROS2 package overlay                                                              \
      source /geographic_msgs/geographic_msgs_ros2/install/setup.bash;                          \
      source /mavros_msgs/mavros_msgs_ros2/install/setup.bash;                                  \
    #                                                                                           \
    #-------------------------------------                                                      \
    # Finally, build the Bridge                                                                 \
    #-------------------------------------                                                      \
    mkdir -p /ros-humble-ros1-bridge/src;                                                       \
    cd /ros-humble-ros1-bridge/src;                                                             \
    git clone -b action_bridge_humble --depth=1 https://github.com/smith-doug/ros1_bridge.git;  \
    cd ros1_bridge/;                                                                            \
    cd ../..;                                                                                   \
    MEMG=$(printf "%.0f" $(free -g | awk '/^Mem:/{print $2}'));                                 \
    NPROC=$(nproc);  MIN=$((MEMG<NPROC ? MEMG : NPROC));                                        \
    #                                                                                           \
    echo "Please wait...  running $MIN concurrent jobs to build ros1_bridge";                   \
    time MAKEFLAGS="-j $MIN" colcon build --event-handlers console_direct+                      \
      --cmake-args -DCMAKE_BUILD_TYPE=Release;

###########################
# 8.) Clean up
###########################
RUN apt-get -y clean all; apt-get -y update;

###########################
# 9.) Pack all ROS1 dependent libraries
###########################
# fix ARM64 pkgconfig path issue -- Fix provided by ambrosekwok
RUN if [[ $(uname -m) = "arm64" || $(uname -m) = "aarch64" ]]; then                    \
      cp /usr/lib/x86_64-linux-gnu/pkgconfig/* /usr/lib/aarch64-linux-gnu/pkgconfig/;  \
    fi;

RUN ROS1_LIBS="libxmlrpcpp.so";                                                 \
     ROS1_LIBS="$ROS1_LIBS librostime.so";                                      \
     ROS1_LIBS="$ROS1_LIBS libroscpp.so";                                       \
     ROS1_LIBS="$ROS1_LIBS libroscpp_serialization.so";                         \
     ROS1_LIBS="$ROS1_LIBS librosconsole.so";                                   \
     ROS1_LIBS="$ROS1_LIBS librosconsole_log4cxx.so";                           \
     ROS1_LIBS="$ROS1_LIBS librosconsole_backend_interface.so";                 \
     ROS1_LIBS="$ROS1_LIBS liblog4cxx.so";                                      \
     ROS1_LIBS="$ROS1_LIBS libcpp_common.so";                                   \
     ROS1_LIBS="$ROS1_LIBS libb64.so";                                          \
     ROS1_LIBS="$ROS1_LIBS libaprutil-1.so";                                    \
     ROS1_LIBS="$ROS1_LIBS libapr-1.so";                                        \
     ROS1_LIBS="$ROS1_LIBS libactionlib.so.1d";                                 \
     cd /ros-humble-ros1-bridge/install/ros1_bridge/lib;                        \
     for soFile in $ROS1_LIBS; do                                               \
       soFilePath=$(ldd libros1_bridge.so | grep $soFile | awk '{print $3;}');  \
       cp $soFilePath ./;                                                       \
     done;

###########################
# 10.) Spit out ros1_bridge tarball by default when no command is given
###########################
RUN tar czf /ros-humble-ros1-bridge.tgz \
     --exclude '*/build/*' --exclude '*/src/*' /ros-humble-ros1-bridge;
ENTRYPOINT []
CMD cat /ros-humble-ros1-bridge.tgz; sync
