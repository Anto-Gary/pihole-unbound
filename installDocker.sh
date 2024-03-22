#!/bin/bash

function install_docker()
{
    # https://phoenixnap.com/kb/docker-on-raspberry-pi
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
}


function add_me_to_docker_group()
{
    DOCKER_GROUP_NAME="docker"

    echo -e "adding '$(whoami)' user to '${DOCKER_GROUP_NAME}' group"
    sudo usermod -aG $DOCKER_GROUP_NAME $(whoami)
    # sudo gpasswd -d $(whoami) docker
    # cat /etc/group | grep docker
}


SETUP_DIR_NAME="DOCKER_SETUP_SCRIPT"
SETUP_DIR_PATH="${PWD}/${SETUP_DIR_NAME}"

# do all setup stuff in a new dir
if [[ ! -d $SETUP_DIR_PATH ]]; then
    mkdir $SETUP_DIR_PATH
fi

# first time setup
cd $SETUP_DIR_PATH


install_docker
add_me_to_docker_group