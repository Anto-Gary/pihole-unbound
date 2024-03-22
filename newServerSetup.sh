#!/bin/bash

function update_and_upgrade()
{
    sudo apt-get update
    sudo apt-get upgrade -y    
}


function install_dependencies()
{
    sudo apt install vim -y
    sudo apt install sqlite3 -y
    sudo apt install dnsutils -y # nslookup, dig, etc.
    sudo apt install net-tools -y # netstat, etc.
}

update_and_upgrade
install_dependencies