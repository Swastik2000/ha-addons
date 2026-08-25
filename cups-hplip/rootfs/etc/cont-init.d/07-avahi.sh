#!/usr/bin/with-contenv bashio
# Home Assistant OS does NOT run Avahi - it uses systemd-resolved plus
# hassio_multicast (mdns-repeater). Both that and Avahi set SO_REUSEADDR on
# 5353, so a second responder binds fine; you only get a "detected another
# IPv4 mDNS stack" warning.
IFACE=$(jq -r '.mdns_interface // ""' /data/options.json 2>/dev/null)


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
