#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/tteck/Proxmox/next/misc/debian.func)
# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    ____  _______________  __      _       ____________ 
   / __ \/ ___/_  __/ __ \/ /_____| |     / / ____/ __ )
  / /_/ /\__ \ / / / /_/ / __/ __ \ | /| / / __/ / __  |
 / _, _/___/ // / / ____/ /_/ /_/ / |/ |/ / /___/ /_/ / 
/_/ |_|/____//_/ /_/    \__/\____/|__/|__/_____/_____/  
                                                        
EOF
}
header_info
echo -e "Loading..."
APP="RSTPtoWEB"
var_disk="4"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="11"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET=dhcp
  GATE=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
header_info
if [[ ! -d /var ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating $APP LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated $APP LXC"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} Setup should be reachable by going to the following URL.
         ${BL}http://${IP}:8083 ${CL} \n"