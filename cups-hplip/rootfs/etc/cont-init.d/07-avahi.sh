#!/usr/bin/with-contenv bashio
# Home Assistant OS does NOT run Avahi - it uses systemd-resolved plus
# hassio_multicast (mdns-repeater). Both that and Avahi set SO_REUSEADDR on
# 5353, so a second responder binds fine; you only get a "detected another
# IPv4 mDNS stack" warning.
IFACE=$(jq -r '.mdns_interface // ""' /data/options.json 2>/dev/null)

# Auto-detect when unset. Advertising on every docker veth and the hassio
# bridge gives AirPrint clients unroutable 172.30.x.x addresses to try; iOS
# reacts by RESUBMITTING the whole job, which prints the same document over
# and over. Bind to the interface holding the default route instead.
# /proc/net/route avoids a dependency on iproute2.
if [ -z "$IFACE" ]; then
    IFACE=$(awk '$2=="00000000" && $8=="00000000" {print $1; exit}' /proc/net/route 2>/dev/null)
    [ -n "$IFACE" ] && bashio::log.info "avahi: auto-detected LAN interface ${IFACE}"
fi

{
  echo "[server]"
  echo "use-ipv4=yes"
  echo "use-ipv6=no"
  # Publishing on every docker veth / the hassio bridge triggers an endless
  # "Host name conflict, retrying with <name>-2" loop, and the printer then
  # never becomes visible to AirPrint. Pin the LAN interface when known.
  [ -n "$IFACE" ] && echo "allow-interfaces=${IFACE}"
  # DO NOT set disallow-other-stacks=yes. systemd-resolved responds by
  # logging "Another mDNS responder prohibits binding the socket to the same
  # port. Turning off mDNS support." and homeassistant.local dies host-wide.
  echo "disallow-other-stacks=no"
  echo "ratelimit-interval-usec=1000000"
  echo "ratelimit-burst=1000"
  echo "[publish]"
  echo "publish-hinfo=no"
  echo "publish-workstation=no"
  echo "[reflector]"
  # Flat home LAN: hassio_multicast already repeats. Reflecting as well only
  # duplicates records.
  echo "enable-reflector=no"
  echo "[rlimits]"
} > /etc/avahi/avahi-daemon.conf

bashio::log.info "avahi: interfaces=${IFACE:-all} reflector=off"
