#!/usr/bin/env bash
if [ "$VERBOSE" = "yes" ]; then set -x; STD=""; else STD="silent"; fi
silent() { "$@" > /dev/null 2>&1; }
if [ "$DISABLEIPV6" == "yes" ]; then echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.conf; $STD sysctl -p; fi
YW=$(echo "\033[33m")
RD=$(echo "\033[01;31m")
BL=$(echo "\033[36m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
RETRY_NUM=10
RETRY_EVERY=3
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"
set -Eeuo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

msg_info "Setting up Container OS "
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null
for ((i=RETRY_NUM; i>0; i--)); do
  if [ "$(hostname -I)" != "" ]; then
    break
  fi
  echo 1>&2 -en "${CROSS}${RD} No Network! "
  sleep $RETRY_EVERY
done
if [ "$(hostname -I)" = "" ]; then
  echo 1>&2 -e "\n${CROSS}${RD} No Network After $RETRY_NUM Tries${CL}"
  echo -e " 🖧  Check Network Settings"
  exit 1
fi
msg_ok "Set up Container OS"
msg_ok "Network Connected: ${BL}$(hostname -I)"

set +e
if ping -c 1 -W 1 1.1.1.1 &> /dev/null; then msg_ok "Internet Connected"; else
  msg_error "Internet NOT Connected"
    read -r -p "Would you like to continue anyway? <y/N> " prompt
    if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then
      echo -e " ⚠️  ${RD}Expect Issues Without Internet${CL}"
    else
      echo -e " 🖧  Check Network Settings"
      exit 1
    fi
fi
RESOLVEDIP=$(getent hosts github.com | awk '{ print $1 }')
if [[ -z "$RESOLVEDIP" ]]; then msg_error "DNS Lookup Failure"; else msg_ok "DNS Resolved github.com to ${BL}$RESOLVEDIP${CL}"; fi
set -e

msg_info "Updating Container OS"
$STD apt-get update
$STD apt-get -y upgrade
msg_ok "Updated Container OS"

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y lsb-base
$STD apt-get install -y lsb-release
$STD apt-get install -y gnupg2
msg_ok "Installed Dependencies"

msg_info "Setting up InfluxDB Repository"
wget -q https://repos.influxdata.com/influxdata-archive_compat.key
cat influxdata-archive_compat.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
sh -c 'echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main" > /etc/apt/sources.list.d/influxdata.list'
msg_ok "Set up InfluxDB Repository"

read -r -p "Which version of InfluxDB to install? (1 or 2) " prompt
if [[ $prompt == "2" ]]; then
  INFLUX="2"
else
  INFLUX="1"
fi

msg_info "Installing InfluxDB"
$STD apt-get update
if [[ $INFLUX == "2" ]]; then
  $STD apt-get install -y influxdb2
else
  $STD apt-get install -y influxdb
fi
$STD systemctl enable --now influxdb
msg_ok "Installed InfluxDB"

read -r -p "Would you like to add Telegraf? <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then
  TELEGRAF="Y"
else
  TELEGRAF="N"
fi

if [[ $TELEGRAF == "Y" ]]; then
  msg_info "Installing Telegraf"
  $STD apt-get install -y telegraf
  msg_ok "Installed Telegraf"
fi

echo "export TERM='xterm-256color'" >>/root/.bashrc
echo -e "\n${APPLICATION} LXC provided by https://tteck.github.io/Proxmox/\n" > /etc/motd
chmod -x /etc/update-motd.d/*
if ! getent shadow root | grep -q "^root:[^\!*]"; then
  msg_info "Customizing Container"
  GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
  mkdir -p $(dirname $GETTY_OVERRIDE)
  cat <<EOF >$GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF
  systemctl daemon-reload
  systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')
  msg_ok "Customized Container"
fi
if [[ "${SSH_ROOT}" == "yes" ]]; then sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config; systemctl restart sshd; fi

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
