#!/bin/bash

###
# DHCP
###

setup_dhcp()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local interface="${1:-wlan0}"
  local dhcp_conf="${2:-${DHCP_CONF}}"
  
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
  result='{"ip":"'${DHCP_IPADDR}'","netsize":'${DHCP_NETSIZE}',"netmask":"'${DHCP_NETMASK}'","start":"'${DHCP_START}'","finish":"'${DHCP_FINISH}'","duration":"'${DHCP_DURATION}'"}'

  echo "${result:-null}"
}

###
## IPTABLES
###

###
## MIT mitm proxy settings
###

MITM=false
MITM_PROXY_PORT=8080
MITM_WEBUI_PORT=8081

start_mitm()
{
  docker run --restart=unless-stopped -d -p ${MITM_PROXY_PORT}:${MITM_PROXY_PORT} -p ${MITM_WEBUI_PORT}:${MITM_WEBUI_PORT} mitmproxy/mitmproxy:latest-ARMv7 mitmweb --web-iface 0.0.0.0
}

setup_iptables()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local interface=${1:-wlan0}
  local bridge=${2:-null}

  # test if legacy required (>= Buster)
  if [ "${IPTABLES_LEGACY:-false}" = 'true' ] && [ ! -z "$(command -v iptables-legacy)" ]; then 
    echo "+++ INFO $0 $$ -- update-alternatives for iptables to legacy"
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
    update-alternatives --set arptables /usr/sbin/arptables-legacy
    update-alternatives --set ebtables /usr/sbin/ebtables-legacy
  fi

  # make script
  echo '#!/bin/bash' > ${IPTABLES_SCRIPT}

  # whenever you want to route
  echo 'iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE' >> ${IPTABLES_SCRIPT}

  # when no bridge
  if [ "${bridge:-null}" = 'null' ]; then
    echo 'iptables -A FORWARD -i eth0 -o '${interface}' -m state --state RELATED,ESTABLISHED -j ACCEPT' >> ${IPTABLES_SCRIPT}
    echo 'iptables -A FORWARD -i '${interface}' -o eth0 -j ACCEPT' >> ${IPTABLES_SCRIPT}
  fi

  # for MIT man-in-the-middle
  if [ "${MITM:-false}" = 'true' ]; then
    echo 'iptables -t nat -A PREROUTING -i '${interface}' -p tcp -m tcp --dport 80 -j REDIRECT --to-ports '${MITM_PROXY_PORT} >> ${IPTABLES_SCRIPT}
    echo 'iptables -t nat -A PREROUTING -i '${interface}' -p tcp -m tcp --dport 443 -j REDIRECT --to-ports '${MITM_PROXY_PORT} >> ${IPTABLES_SCRIPT}
  fi

  chmod 755 ${IPTABLES_SCRIPT}

  # make service
  echo '[Unit]' > ${IPTABLES_SERVICE}
  echo 'Description=iptables for access point' >> ${IPTABLES_SERVICE}
  echo 'After=network-pre.target' >> ${IPTABLES_SERVICE}
  echo 'Before=network-online.target' >> ${IPTABLES_SERVICE}
  echo '[Service]' >> ${IPTABLES_SERVICE}
  echo 'Type=simple' >> ${IPTABLES_SERVICE}
  echo "ExecStart=${IPTABLES_SCRIPT}" >> ${IPTABLES_SERVICE}
  echo '[Install]' >> ${IPTABLES_SERVICE}
  echo 'WantedBy=multi-user.target' >> ${IPTABLES_SERVICE}

  result='{"script":"'${IPTABLES_SCRIPT}'","service":"'${IPTABLES_SERVICE}'"}'

  # enable
  systemctl unmask iptables &> /dev/stderr
  systemctl enable iptables &> /dev/stderr
  systemctl start iptables &> /dev/stderr

  echo "${result:-null}"
}


###
# DNSMASQ
###

setup_dnsmasq()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local interface="${1:-wlan0}"
  local dnsmasq_conf="${2:-${DNSMASQ_CONF}}"
  local dhcp_conf="${3:-${DHCP_CONF}}"

  local version=$(dnsmasq --version | head -1 | awk '{ print $3 }')
  local major=${version%.*}
  local minor=${version#*.}

  if [ ${major:-0} -ge 2 ] && [ ${minor} -ge 77 ]; then
    echo "DNSMASQ; version; ${version}" &> /dev/stderr
  else
    echo "DNSMASQ; version; ${version}; removing dns-root-data" &> /dev/stderr
    apt -qq -y --purge remove dns-root-data
  fi

  local dhcp=$(setup_dhcp ${interface} ${dhcp_conf})
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

  # enable services
  systemctl unmask dnsmasq &> /dev/stderr
  systemctl enable dnsmasq &> /dev/stderr
  systemctl start dnsmasq &> /dev/stderr
  systemctl unmask dhcpcd &> /dev/stderr
  systemctl enable dhcpcd &> /dev/stderr
  systemctl start dhcpcd &> /dev/stderr

  ## report
  result='{"version":"'${version}'","dhcp":'${dhcp}',"options":["bind-dynamic","domain-needed","bogus-priv"]}'

  echo "${result:-null}"
}

###
# BRIDGE
###

setup_bridge()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local interface="${1:-wlan0}"; shift
  local bridge=${1:-br0}; shift
  local dns_nameservers="${*:-${DNS_NAMESERVERS}}"

  if [ $(brctl show | egrep "${bridge}" | wc -l) -le 1 ]; then
    echo "+++ INFO $0 $$ -- building bridge ${bridge} to eth0" &> /dev/stderr
    brctl addbr ${bridge}
    #brctl addif ${bridge} eth0
  else
    echo "+++ INFO $0 $$ -- existing bridge ${bridge}; not making" &> /dev/stderr
  fi

  if [ -s ${NETWORK_CONF} ]; then
    if [ ! -s "${NETWORK_CONF}.bak" ]; then
      cp ${NETWORK_CONF} ${NETWORK_CONF}.bak
    else
      cp ${NETWORK_CONF}.bak ${NETWORK_CONF}
    fi
  fi

  # append
  echo "auto ${bridge}" >> ${NETWORK_CONF}
  echo "iface ${bridge} inet manual" >> ${NETWORK_CONF}
  echo "bridge_ports eth0 ${interface}" >> ${NETWORK_CONF}
  echo "dns-nameservers ${dns_nameservers}" >> ${NETWORK_CONF}

  # report
  result='{"name":"'${bridge}'","interface":"'${interface}'","dns_nameservers":"'${dns_nameservers}'"}'

  echo "${result:-null}"
}

###
# HOSTAPD
###

setup_hostapd()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local setup="${*:-null}"
  local interface=$(echo "${setup}" | jq -r '.interface')
  local bridge=$(echo "${setup}" | jq -r '.bridge.name')

  local channel=${CHANNEL:-8}
  local ssid=${SSID:-TEST}
  local wpa_passphrase=${WPA_PASSPHRASE:-0123456789}
  local hw_mode=${HW_MODE:-g}
  local wpa=${WPA_MODE:-2}

  sed -i 's|.*DAEMON_CONF=.*|DAEMON_CONF='${HOSTAPD_CONF}'|' "${HOSTAPD_DEFAULT}"

  # overwrite
  echo "interface=${interface}" > ${HOSTAPD_CONF}
  echo "hw_mode=${hw_mode}" >> ${HOSTAPD_CONF}
  echo "channel=${channel}" >> ${HOSTAPD_CONF}
  echo "wpa=${wpa}" >> ${HOSTAPD_CONF}
  echo "ssid=${ssid}" >> ${HOSTAPD_CONF}
  echo "wpa_passphrase=${wpa_passphrase}" >> ${HOSTAPD_CONF}

  # bridge (or not)
  if [ "${bridge:-null}" != 'null' ]; then echo "bridge=${bridge}" >> ${HOSTAPD_CONF}; fi

  # static
  echo "wmm_enabled=0" >> ${HOSTAPD_CONF}
  echo "macaddr_acl=0" >> ${HOSTAPD_CONF}
  echo "auth_algs=1" >> ${HOSTAPD_CONF}
  echo "ignore_broadcast_ssid=0" >> ${HOSTAPD_CONF}
  echo "wpa_key_mgmt=WPA-PSK" >> ${HOSTAPD_CONF}
  echo "wpa_pairwise=TKIP" >> ${HOSTAPD_CONF}
  echo "rsn_pairwise=CCMP" >> ${HOSTAPD_CONF}
  echo "ctrl_interface=/var/run/hostapd" >> ${HOSTAPD_CONF}

  result='{"interface":"'${interface}'","channel":'${channel}',"bridge":"'${bridge}'","hw_mode":"'${hw_mode}'","wpa":'${wpa}',"ssid":"'${ssid}'","wpa_passphrase":"'${wpa_passphrase}'"}'

  systemctl unmask hostapd &> /dev/stderr
  systemctl enable hostapd &> /dev/stderr
  systemctl start hostapd &> /dev/stderr

  echo "${result:-null}"
}

###
## /etc/sysctl.conf
###

enable_ipv4_forward()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  sed -i 's|.*net.ipv4.ip_forward.*|net.ipv4.ip_forward=1|' "${SYSCTL_CONF}"
  echo 1 > /proc/sys/net/ipv4/ip_forward
}

## build a bridge
setup_device()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local interface="${1:-wlan0}"
  local bridge="${2:-null}"
  local result 

  if [ "${bridge:-null}" != 'null' ]; then
    local bridge=$(setup_bridge ${interface} ${bridge})

    echo "... TRACE: ${FUNCNAME[0]}: bridge: ${bridge:-null}" &> /dev/stderr

    if [ "${bridge:-null}" != 'null' ]; then
      result='{"date":"'$(date -u +%FT%TZ)'","interface":"'${interface}'","bridge":'"${bridge}"'}'

      if [ ! -z "$(command -v dnsmasq)" ]; then
        echo "+++ INFO $0 $$ -- stopping and disabling dnsmasq and dhcpcd" &> /dev/stderr
        systemctl stop dhcpcd &> /dev/stderr
        systemctl disable dhcpcd &> /dev/stderr
        systemctl stop dnsmasq &> /dev/stderr
        systemctl disable dnsmasq &> /dev/stderr
      fi
    else
      echo "*** ERROR $0 $$ -- failed to setup bridge" &> /dev/stderr
    fi
  else
    local dnsmasq=$(setup_dnsmasq ${interface})

    if [ "${dnsmasq:-null}" != 'null' ]; then
      result='{"date":"'$(date -u +%FT%TZ)'","interface":"'${interface}'","dnsmasq":'${dnsmasq}'}'
    else
      echo "*** ERROR $0 $$ -- failed to setup dnsmasq" &> /dev/stderr
    fi
  fi

  # if successful, setup iptables
  if [ "${result:-null}" != 'null' ]; then
    local iptables=$(setup_iptables ${interface} ${bridge})

    if [ "${iptables:-null}" != 'null' ]; then
      result=$(echo "${result}" | jq -c '.iptables='"${iptables}")
    fi
  fi

  # enable forwarding packages for IPv4
  enable_ipv4_forward

  echo "${result:-null}"
}

package_check()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local bridge="${1:-null}"
  local result
  local packages=()
  local commands=
 
  if [ "${bridge:-null}" != 'null' ]; then
    commands="jq hostapd brctl nslookup"
  else
    commands="jq hostapd dnsmasq nslookup"
  fi

  for pr in ${commands}; do
    if [ -z "$(command -v ${pr})" ]; then
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
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local result
  local bridge=${1:-null}
  local missing=$(package_check ${bridge}) 

  if [ "${missing:-null}" != 'null' ]; then
    echo "*** ERROR $0 $$ -- install packages: ${missing[@]}; apt install -qq -y ${missing[@]}" &> /dev/stderr
  else
    result='true'
  fi
  echo "${result:-false}"
}

## build the bridge
rpi_bridge()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "--- FUNCTION: ${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local result
  local bridge=${1:-null}
  local interface=${2:-wlan0}

  echo "+++ INFO $0 $$ -- installing; bridge: ${bridge}" &> /dev/stderr

  if [ "$(required_packages ${bridge})" = 'true' ]; then
    # turn off
    if [ ! -z "$(command -v dnsmasq)" ]; then systemctl stop dnsmasq &> /dev/stderr; fi
    if [ ! -z "$(command -v dhcpcd)" ]; then systemctl stop dhcpcd &> /dev/stderr; fi
    if [ ! -z "$(command -v hostapd)" ]; then systemctl stop hostapd &> /dev/stderr; fi

    # setup
    result=$(setup_device ${interface} ${bridge})

    echo "... TRACE: ${FUNCNAME[0]}: result: ${result:-null}" &> /dev/stderr

    # reload
    if [ "${result:-null}" != 'null' ]; then
      local hostapd=$(setup_hostapd "${result}")
      if [ "${hostapd:-null}" != 'null' ]; then
        result=$(echo "${result}" | jq -c '.hostapd='"${hostapd}")

        systemctl daemon-reload &> /dev/stderr
      else
        echo "*** ERROR $0 $$ -- hostapd setup failed" &> /dev/stderr
      fi
    else
      echo "*** ERROR $0 $$ -- device setup failed" &> /dev/stderr
    fi
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
WPA_PASSPHRASE=${WPA_PASSPHRASE:-0123456789}
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
SYSCTL_CONF="/etc/sysctl.conf"
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


# doc
echo "USAGE: ${0} [ br0 ]" &> /dev/stderr
echo "OPTIONS: bridge optional; environment: SSID: ${SSID}, WPA_PASSPHRASE: ${WPA_PASSPHRASE}, CHANNEL: ${CHANNEL}, DNS_NAMESERVERS: ${DNS_NAMESERVERS}" &> /dev/stderr

# root?
if [ $(whoami) != "root" ]; then echo "*** ERROR $0 $$ -- run as root" &> /dev/stderr; exit 1; fi

# doit
rpi_bridge ${*} | jq '.'
