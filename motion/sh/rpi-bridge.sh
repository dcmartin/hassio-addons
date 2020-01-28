#!/bin/bash

if [ $(arch) != "armv7l" ]; then
  echo "*** ERROR $0 $$ -- for RaspberryPi only"
  exit 1
fi

if [ $(whoami) != "root" ]; then
  echo "*** ERROR $0 $$ -- run as root"
  exit 1
fi

if [ -z "${DNS_NAMESERVERS:-}" ]; then
  DNS_NAMESERVERS="9.9.9.9"
  echo "$(date '+%T') INFO $0 $$ -- no DNS name-servers specified; using: ${DNS_NAMESERVERS}"
fi

if [ -z "${HW_MODE:-}" ]; then
  HW_MODE="g"
  echo "$(date '+%T') INFO $0 $$ -- no hw_mode specified; using: ${HW_MODE}"
fi
if [ -z "${CHANNEL:-}" ]; then
  case "${HW_MODE}" in
    "g")
      CHANNEL=8
      ;;
    "a")
      if [ $(arch) == "armv7l" ]; then
        echo "+++ WARN $0 $$ -- may not by supported by $(arch); hw_mode: ${HW_MODE}; run systemctl status hostapd"
      fi
      CHANNEL=38
      ;;
    *)
      CHANNEL=7
      ;;
  esac
  echo "$(date '+%T') INFO $0 $$ -- no channel specified; using: ${CHANNEL}"
fi

SSID=${SSID:-TEST}
echo "$(date '+%T') INFO $0 $$ -- SSID: ${SSID}"

WPA_PASSWORD=${WPA_PASSWORD:-0123456789}
echo "$(date '+%T') INFO $0 $$ -- WPA_PASSWORD: ${WPA_PASSWORD}"

packages=()
for pr in hostapd dnsmasq brctl nslookup; do
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
  echo "*** ERROR $0 $$ -- install packages: ${packages[@]}"
  exit
fi

systemctl stop dnsmasq
systemctl stop hostapd

###
# DHCP
###

DHCP_CONF="/etc/dhcpcd.conf"
DHCP_IPADDR=${DHCP_IPADDR:-192.168.0.2}
DHCP_START=${DHCP_START:-192.168.0.3}
DHCP_FINISH=${DHCP_FINISH:-192.168.0.254}
DHCP_NETMASK=${DHCP_NETMASK:-255.255.255.0}
DHCP_NETSIZE=${DHCP_NETSIZE:-24}
DHCP_DURATION=${DHCP_DURATION:-24h}

if [ -s "${DHCP_CONF}" ]; then
  if [ ! -s "${DHCP_CONF}.bak" ]; then
    cp ${DHCP_CONF} ${DHCP_CONF}.bak
  else
    cp ${DHCP_CONF}.bak ${DHCP_CONF}
  fi
fi

## append
echo 'nohook wpa_supplicant' >> "${DHCP_CONF}"
#echo 'denyinterfaces wlan0' >> "${DHCP_CONF}"
#echo 'denyinterfaces eth0' >> "${DHCP_CONF}"
echo 'interface wlan0' >> "${DHCP_CONF}"
echo "static ip_address=${DHCP_IPADDR}/${DHCP_NETSIZE}" >> "${DHCP_CONF}"
echo "static routers=192.168.0.1" >> "${DHCP_CONF}"
echo "static domain_name_servers=192.168.1.50 192.168.1.40 9.9.9.9" >> "${DHCP_CONF}"

## report
echo "$(date '+%T') INFO $0 $$ -- configured DHCP: ${DHCP_CONF}; ip=${DHCP_IPADDR}; netsize: ${DHCP_NETSIZE}; netmask: ${DHCP_NETMASK}; start: ${DHCP_START}; finish: ${DHCP_FINISH}; duration: ${DHCP_DURATION}"

###
# DNSMASQ
###

version=$(dnsmasq --version | head -1 | awk '{ print $3 }') && major=${version%.*} && minor=${version#*.}
if [ ${major:-0} -ge 2 ] && [ ${minor} -ge 77 ]; then
  echo "DNSMASQ; version; ${version}"
else
  echo "DNSMASQ; version; ${version}; removing dns-root-data"
  apt -qq -y --purge remove dns-root-data
fi

DNSMASQ_CONF="/etc/dnsmasq.conf"
if [ -s "${DNSMASQ_CONF}" ]; then
  if [ ! -s "${DNSMASQ_CONF}.bak" ]; then
    cp ${DNSMASQ_CONF} ${DNSMASQ_CONF}.bak
  else
    cp ${DNSMASQ_CONF}.bak ${DNSMASQ_CONF}
  fi
fi

# overwrite
echo 'interface=wlan0' > "${DNSMASQ_CONF}"
echo 'bind-dynamic' >> "${DNSMASQ_CONF}"
echo 'domain-needed' >> "${DNSMASQ_CONF}"
echo 'bogus-priv' >> "${DNSMASQ_CONF}"
echo "dhcp-range=${DHCP_START},${DHCP_FINISH},${DHCP_NETMASK},${DHCP_DURATION}" >> "${DNSMASQ_CONF}"

# report
echo "$(date '+%T') INFO $0 $$ -- configured DNSMASQ" $(cat ${DNSMASQ_CONF})

###
# BRIDGE
###

if [ "${BRIDGING:-false}" = 'true' ]; then
  if [ $(brctl show | egrep 'br0' | wc -l) -le 1 ]; then
    echo "$(date '+%T') INFO $0 $$ -- building bridge br0 to eth0"
    brctl addbr br0
    brctl addif br0 eth0
  else
    echo "$(date '+%T') INFO $0 $$ -- existing bridge br0; not making"
  fi

  NETWORK_CONF="/etc/network/interfaces"
  if [ -s ${NETWORK_CONF} ]; then
    if [ ! -s "${NETWORK_CONF}.bak" ]; then
      cp ${NETWORK_CONF} ${NETWORK_CONF}.bak
    else
      cp ${NETWORK_CONF}.bak ${NETWORK_CONF}
    fi
  fi

  # append
  echo 'auto br0' >> ${NETWORK_CONF}
  echo 'iface br0 inet manual' >> ${NETWORK_CONF}
  echo 'bridge_ports eth0 wlan0' >> ${NETWORK_CONF}
  echo 'dns-nameservers' "${DNS_NAMESERVERS}" >> ${NETWORK_CONF}

  # report
  echo "$(date '+%T') INFO $0 $$ -- configured NETWORK: ${NETWORK_CONF}"
fi


###
# HOSTAPD
###

HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
if [ -s ${HOSTAPD_CONF} ]; then
  if [ ! -s "${HOSTAPD_CONF}.bak" ]; then
    cp ${HOSTAPD_CONF} ${HOSTAPD_CONF}.bak
  else
    cp ${HOSTAPD_CONF}.bak ${HOSTAPD_CONF}
  fi
fi

# default
HOSTAPD_DEFAULT="/etc/default/hostapd"
echo "$(date '+%T') INFO $0 $$ -- setting configuration default ${HOSTAPD_DEFAULT}; DAEMON_CONF=${HOSTAPD_CONF}"
sed -i 's|.*DAEMON_CONF=.*|DAEMON_CONF='${HOSTAPD_CONF}'|' "${HOSTAPD_DEFAULT}"

# overwrite
echo 'interface=wlan0' > ${HOSTAPD_CONF}
echo 'hw_mode='"${HW_MODE}" >> ${HOSTAPD_CONF}
echo 'channel='"${CHANNEL}" >> ${HOSTAPD_CONF}
echo 'wmm_enabled=0' >> ${HOSTAPD_CONF}
echo 'macaddr_acl=0' >> ${HOSTAPD_CONF}
echo 'auth_algs=1' >> ${HOSTAPD_CONF}
echo 'ignore_broadcast_ssid=0' >> ${HOSTAPD_CONF}
echo 'wpa=2' >> ${HOSTAPD_CONF}
echo 'wpa_key_mgmt=WPA-PSK' >> ${HOSTAPD_CONF}
echo 'wpa_pairwise=TKIP' >> ${HOSTAPD_CONF}
echo 'rsn_pairwise=CCMP' >> ${HOSTAPD_CONF}
echo 'ssid='"${SSID}" >> ${HOSTAPD_CONF}
echo 'wpa_passphrase='"${WPA_PASSWORD}" >> ${HOSTAPD_CONF}

if [ "${BRIDGING:-false}" = 'true' ]; then
  echo 'bridge=br0' >> ${HOSTAPD_CONF}
fi

# report
echo "$(date '+%T') INFO $0 $$ -- configured hostapd: ${HOSTAPD_CONF}; ssid: ${SSID}; mode: ${HW_MODE}; channel: ${CHANNEL}; password: ${WPA_PASSWORD}"

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
## /etc/iptables
###

if [ ! -z $(command -v "iptables-legacy") ]; then IPTABLES='iptables-legacy'; else IPTABLES='iptables'; fi

cat > /etc/iptables.sh << EOF
#!/bin/bash
${IPTABLES} -t nat -A POSTROUTING -o eth0 -j MASQUERADE
${IPTABLES} -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
${IPTABLES} -A FORWARD -i wlan0 -o eth0 -j ACCEPT
EOF
chmod 755 /etc/iptables.sh

## systemd
cat > /etc/systemd/system/iptables.service << EOF
[Unit]
Description=iptables for access point
After=network-pre.target
Before=network-online.target

[Service]
Type=simple
ExecStart=/etc/iptables.sh

[Install]
WantedBy=multi-user.target
EOF

# enable
systemctl enable iptables

# start
echo "$(date '+%T') INFO $0 $$ -- restarting daemons"
systemctl unmask hostapd
systemctl enable hostapd
systemctl restart hostapd
systemctl restart dnsmasq

# reload
echo "$(date '+%T') INFO $0 $$ -- reloading daemons"
systemctl daemon-reload
