ARG USER=ros
ARG USER_UID=1000
ARG USER_GID=1000
ARG ROS_DISTRO=jazzy 

FROM --platform=linux/arm64 docker.io/samxl/jetson_ros:r36.4-jazzy AS deps

# Redefine them to be used in this scope
ARG USER
ARG USER_UID
ARG USER_GID
ARG ROS_DISTRO

# Delete user if it exists in container (e.g Ubuntu Noble: ubuntu)
RUN if id -u $USER_UID ; then userdel `id -un $USER_UID` ; fi

# Create the user
RUN groupadd --gid $USER_GID $USER \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USER \
    && apt-get update && apt-get install -y \
        bash-completion \
        openssh-client \
        sudo \
    && rm -rf /var/lib/apt/lists/* \
    && rm /etc/apt/apt.conf.d/docker-clean \
    && echo $USER ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER \
    && echo "source /opt/ros/jazzy/setup.bash" >> /home/${USER}/.bashrc

# Create ros2_ws and copy files
WORKDIR /home/$USER/ros2_ws
SHELL ["/bin/bash", "-c"]
COPY . /home/$USER/ros2_ws/src
RUN chown -R ros:ros . 

# Install dependencies
RUN apt-get update \
    && apt-get -y --quiet --no-install-recommends install \
    gcc \
    git \
    wget \
    python3 \
    python3-pip

USER $USER

# Clone behavior_tree if ROS_DISTRO is rolling
RUN if [ "$ROS_DISTRO" = "rolling" ]; then \
    git clone https://github.com/BehaviorTree/BehaviorTree.CPP src/BehaviorTree.CPP; \
    fi

# Install rosdep
RUN sudo apt update && sudo rosdep init && rosdep update && rosdep install --from-paths src --ignore-src -r -y

# Install all Python Reqs
RUN sudo /opt/venv/bin/pip install -r src/requirements.txt --break-system-packages --ignore-installed --index-url https://pypi.org/simple/ 

# Colcon the ws
FROM deps AS builder
USER $USER
WORKDIR /home/$USER/ros2_ws

ARG CMAKE_BUILD_TYPE=Release
ARG ROS_DISTRO

#MOVING BUILD STAGE INTO CONTAINER

# Source the ROS 2 setup file
RUN echo "source /home/$USER/ros2_ws/install/setup.bash" >> ~/.bashrc

# Run a default command, e.g., starting a bash shell
CMD ["bash"]
