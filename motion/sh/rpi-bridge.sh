#!/bin/bash

###
# DHCP
###

setup_dhcp()
{
  local dhcp_conf="${1:-${DHCP_CONF}}"
  local interface="${2:-wlan0}"
  
  if [ -s "${dhcp_conf}" ]; then
    if [ ! -s "${dhcp_conf}.bak" ]; then
      cp ${dhcp_conf} ${dhcp_conf}.bak
    else
      cp ${dhcp_conf}.bak ${dhcp_conf}
    fi
  fi

  ## append
  echo 'nohook wpa_supplicant' >> "${dhcp_conf}"
  echo "interface ${interface}" >> "${dhcp_conf}"
  echo "static ip_address=${DHCP_IPADDR}/${DHCP_NETSIZE}" >> "${dhcp_conf}"
  echo "static routers=${DHCP_ROUTER}" >> "${dhcp_conf}"
  echo "static domain_name_servers=${DHCP_DNS}" >> "${dhcp_conf}"

  ## report
  result='{"date":'$(date +%T)',"ip":"'${DHCP_IPADDR}'","netsize":'${DHCP_NETSIZE}',"netmask":"'${DHCP_NETMASK}'","start":"'${DHCP_START}'","finish":"'${DHCP_FINISH}'","duration":"'${DHCP_DURATION}'"}'

  echo "${result:-null}"
}

###
# DNSMASQ
###

setup_dnsmasq()
{
  local dnsmasq_conf="${1:-${DNSMASQ_CONF}}"
  local dhcp_conf="${2:-${DHCP_CONF}}"
  local interface="${3:-wlan0}"

  local version=$(dnsmasq --version | head -1 | awk '{ print $3 }')
  local major=${version%.*}
  local minor=${version#*.}

  if [ ${major:-0} -ge 2 ] && [ ${minor} -ge 77 ]; then
    echo "DNSMASQ; version; ${version}"
  else
    echo "DNSMASQ; version; ${version}; removing dns-root-data"
    apt -qq -y --purge remove dns-root-data
  fi

  local dhcp=$(setup_dhcp ${dhcp_conf} ${interface})
  local start=$(echo "${dhcp}" | jq -r '.start')
  local finish=$(echo "${dhcp}" | jq -r '.finish')
  local netmask=$(echo "${dhcp}" | jq -r '.netmask')
  local netsize=$(echo "${dhcp}" | jq -r '.netsize')
  local duration=$(echo "${dhcp}" | jq -r '.duration')

  # overwrite
  echo "interface=${interface}" > "${dnsmasq_conf}"
  echo 'bind-dynamic' >> "${dnsmasq_conf}"
  echo 'domain-needed' >> "${dnsmasq_conf}"
  echo 'bogus-priv' >> "${dnsmasq_conf}"
  echo "dhcp-range=${start},${finish},${netmask},${duration}" >> "${dnsmasq_conf}"

  ## report
  result='{"date":'$(date +%T)',"version":"'${version}'","interface":"'${interface}'","dhcp":'${dhcp}',"finish":"'${finish}'","netmask":"'${netmask}'","duration":"'${duration}'","options":["bind-dynamic","domain-needed","bogus-priv"]}'

  systemctl unmask dnsmasq
  systemctl enable dnsmasq

  echo "${result:-null}"
}

###
# BRIDGE
###

setup_network()
{
  local bridge=${1:-br0}
  shift
  local interface="${1:-wlan0}"
  shift
  local dns_nameservers="${*:-${DNS_NAMESERVERS}}"

  if [ $(brctl show | egrep "${bridge}" | wc -l) -le 1 ]; then
    echo "$(date '+%T') INFO $0 $$ -- building bridge ${bridge} to eth0"
    brctl addbr ${bridge}
    #brctl addif ${bridge} eth0
  else
    echo "$(date '+%T') INFO $0 $$ -- existing bridge br0; not making"
  fi

  if [ -s ${network_conf} ]; then
    if [ ! -s "${network_conf}.bak" ]; then
      cp ${network_conf} ${network_conf}.bak
    else
      cp ${network_conf}.bak ${network_conf}
    fi
  fi

  # append
  echo "auto ${bridge}" >> ${network_conf}
  echo "iface ${bridge} inet manual" >> ${network_conf}
  echo "bridge_ports eth0 ${interface}" >> ${network_conf}
  echo "dns-nameservers ${dns_nameservers}" >> ${network_conf}

  # report
  result='{"date":'$(date +%T)',"bridge":"'${bridge}'","interface":"'${interface}'","dns_nameservers":"'${dns_nameservers}'"}'

  echo "${result:-null}"
}

###
# HOSTAPD
###

setup_hostapd()
{
  local default=${1:-${HOSTAPD_DEFAULT}}
  local conf=${2:-${HOSTAPD_CONF}}
  local interface=${3:-wlan0}
  local channel=${4:-${CHANNEL}}
  local ssid=${5:-${SSID}}
  local password=${5:-${WPA_PASSWORD}}
  local hw_mode=${7:-${HW_MODE}}
  local wpa=${7:-2}

  echo "$(date '+%T') INFO $0 $$ -- setting configuration default ${HOSTAPD_DEFAULT}; DAEMON_CONF=${HOSTAPD_CONF}"

  sed -i 's|.*DAEMON_CONF=.*|DAEMON_CONF='${HOSTAPD_CONF}'|' "${HOSTAPD_DEFAULT}"

  # overwrite
  echo "interface=${interface}" > ${conf}
  echo "hw_mode=${hw_mode}" >> ${conf}
  echo "channel=${channel}" >> ${conf}
  echo "wpa=${wpa}" >> ${conf}
  echo "ssid=${ssid}" >> ${conf}
  echo "wpa_passphrase=${wpa_password}" >> ${conf}
  # static
  echo "wmm_enabled=0" >> ${conf}
  echo "macaddr_acl=0" >> ${conf}
  echo "auth_algs=1" >> ${conf}
  echo "ignore_broadcast_ssid=0" >> ${conf}
  echo "wpa_key_mgmt=WPA-PSK" >> ${conf}
  echo "wpa_pairwise=TKIP" >> ${conf}
  echo "rsn_pairwise=CCMP" >> ${conf}
  echo "ctrl_interface=/var/run/hostapd" >> ${conf}

  if [ "${BRIDGE:-false}" = 'true' ]; then
    echo 'bridge=br0' >> ${conf}
  fi

  result='{"date":'$(date +%T)',"interface":"'${interface}'","channel":'${channel}',"hw_mode":"'${hw_mode}'","wpa":'${wpa}',"ssid":"'${ssid}'","wpa_passphrase":"'${password}'"}'

  systemctl unmask hostapd
  systemctl enable hostapd

  echo "${result:-null}"
}

###
## /etc/sysctl.conf
###

SYSCTL_CONF="/etc/sysctl.conf"
if [ -z "$(egrep '^net.ipv4.ip_forward=' "${SYSCTL_CONF}")" ]; then
  echo "$(date '+%T') INFO $0 $$ -- enabling IPv4 forwarding in ${SYSCTL_CONF}"
  sed -i 's|.*net.ipv4.ip_forward.*|net.ipv4.ip_forward=1|' "${SYSCTL_CONF}"
else
  echo "$(date '+%T') INFO $0 $$ -- existing IPv4 forwarding" $(egrep "^net.ipv4.ip_forward=" ${SYSCTL_CONF})
fi
echo 1 > /proc/sys/net/ipv4/ip_forward

###
## IPTABLES
###

setup_iptables()
{
  local interface=${1:-wlan0}
  local script=${2:-${IPTABLES_SCRIPT}}
  local service=${3:-${IPTABLES_SERVICE}}

  # test if legacy required (>= Buster)
  if [ "${IPTABLES_LEGACY:-false}" = 'true' ] && [ ! -z $(command -v "iptables-legacy") ]; then 
    echo "$(date '+%T') INFO $0 $$ -- update-alternatives for iptables to legacy"
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
    update-alternatives --set arptables /usr/sbin/arptables-legacy
    update-alternatives --set ebtables /usr/sbin/ebtables-legacy
  fi

  # make script
  echo '#!/bin/bash' > ${iptables_script}
  echo 'iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE' >> ${iptables_script}
  echo 'iptables -A FORWARD -i eth0 -o '${interface}' -m state --state RELATED,ESTABLISHED -j ACCEPT' >> ${iptables_script}
  echo 'iptables -A FORWARD -i '${interface}' -o eth0 -j ACCEPT' >> ${iptables_script}
  chmod 755 ${iptables_script}

  # make service
  echo '[Unit]' > ${iptables_service}
  echo 'Description=iptables for access point' >> ${iptables_service}
  echo 'After=network-pre.target' >> ${iptables_service}
  echo 'Before=network-online.target' >> ${iptables_service}
  echo '[Service]' >> ${iptables_service}
  echo 'Type=simple' >> ${iptables_service}
  echo "ExecStart=${iptables_service}" >> ${iptables_service}
  echo '[Install]' >> ${iptables_service}
  echo 'WantedBy=multi-user.target' >> ${iptables_service}

  result='{"date":'$(date +%T)',"interface":"'${interface}'","channel":'${channel}',"hw_mode":"'${hw_mode}'","wpa":'${wpa}',"ssid":"'${ssid}'","wpa_passphrase":"'${password}'"}'

  # enable
  systemctl unmask iptables
  systemctl enable iptables

  echo "${result:-null}"
}

setup()
{
  local bridge="${1:-false}"
  local result 

  if [ "${bridge:-false}" = 'true' ]; then
    result=$(setup_network ${NETWORK_CONF})

    if [ ! -z $(command -v "dnsmasq") ]; then
      echo "$(date '+%T') INFO $0 $$ -- stopping and disabling dnsmasq"
      systemctl stop dnsmasq
      systemctl disable dnsmasq
    fi
  else
    result=$(setup_dnsmasq ${DNSMASQ_CONF})

    if [ "${setup:-null}" != 'null' ]; then
      systemctl restart dnsmasq
      systemctl restart hostapd
    else
      echo "*** ERROR $0 $$ -- failed to setup dnsmasq"
    fi
  fi
  echo "${result:-null}"
}

package_check()
{
  local bridge="${1:-false}"
  local result
  local packages=()
  local commands=
 
  if [ "${bridge:-false}" = 'true' ]; then
    commands="hostapd brctl nslookup"
  else
    commands="hostapd dnsmasq nslookup"
  fi

  for pr in ${commands}; do
    if [ -z $(command -v "${pr}") ]; then
      case "${pr}" in
        "brctl")
          packages=(${packages[@]} "bridge-utils")
          ;;
        "nslookup")
          packages=(${packages[@]} "dnsutils")
          ;;
        *)
          packages=(${packages[@]} "${pr}")
          ;;
      esac
    fi
  done

  if [ ${#packages[@]} -gt 0 ]; then
    result="${packages[@]}"
  fi

  echo "${result:-null}"
}

# check package installation
required_packages()
{
  local result
  local bridge=${1:-false}
  local missing=$(package_check ${bridge}) 

  if [ "${missing:-null}" != 'null' ]; then
    echo "*** ERROR $0 $$ -- install packages: ${missing[@]}; apt install -qq -y ${missing[@]}"
  else
    result='true'
  fi
  echo "${result:-false}"
}

## build the bridge
rpi_bridge()
{
  local result
  local bridge=${1:-false}

  echo "+++ INFO $0 $$ -- installing; bridge: ${bridge}"

  if [ $(required_packages ${bridge}) = 'true' ]; then
    # turn off
    if [ ! -z $(command -v "dnsmasq") ]; then systemctl stop dnsmasq; fi
    if [ ! -z $(command -v "hostapd") ]; then systemctl stop hostapd; fi

    # setup
    result=$(setup ${bridge})

    # reload
    systemctl daemon-reload
  fi

  echo "${result:-null}"
}

###
### defaults
###

## generated
HOST_IPADDR=$(hostname -I | awk '{ print $1 }')
HOSTIP=${HOST_IPADDR##*.}

## dynamic
SSID=${SSID:-TEST}
WPA_PASSWORD=${WPA_PASSWORD:-0123456789}
DNS_NAMESERVERS="${DNS_NAMESERVERS:-9.9.9.9 1.1.1.1}"
CHANNEL=${CHANNEL:-8}

## only G on Model3b+
HW_MODE=${HW_MODE:-g}

## dhcp
DHCP_DNS=${DHCP_DNS:-${DNS_NAMESERVERS}}
DHCP_IPADDR=${DHCP_IPADDR:-192.168.${HOSTIP}.1}
DHCP_ROUTER=${DHCP_ROUTER:-${DHCP_IPADDR}}
DHCP_START=${DHCP_START:-192.168.${HOSTIP}.2}
DHCP_FINISH=${DHCP_FINISH:-192.168.${HOSTIP}.254}
DHCP_NETMASK=${DHCP_NETMASK:-255.255.255.0}
DHCP_NETSIZE=${DHCP_NETSIZE:-24}
DHCP_DURATION=${DHCP_DURATION:-24h}

## static
NETWORK_CONF="/etc/network/interfaces"
DHCP_CONF="/etc/dhcpcd.conf"
DNSMASQ_CONF="/etc/dnsmasq.conf"
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
HOSTAPD_DEFAULT="/etc/default/hostapd"
IPTABLES_SCRIPT="/etc/iptables.sh"
IPTABLES_SERVICE="/etc/systemd/system/iptables.service"

###
### MAIN
###

if [ $(whoami) != "root" ]; then echo "*** ERROR $0 $$ -- run as root"; exit 1; fi

rpi_bridge ${*}
