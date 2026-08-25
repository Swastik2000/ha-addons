#!/usr/bin/with-contenv bash
set -e

CFG=/share/cups/config
mkdir -p "$CFG"/ppd "$CFG"/ssl /share/cups/cache /share/cups/logs /share/cups/state
chown -R root:lp /share/cups
chmod -R 755 /share/cups

# --- cupsd.conf ---------------------------------------------------
cat > "$CFG"/cupsd.conf <<'EOL'
LogLevel info
MaxLogSize 10m
Listen 0.0.0.0:631
Listen /run/cups/cups.sock

# advertise queues over mDNS/DNS-SD so AirPrint clients find them
Browsing On
BrowseLocalProtocols dnssd
DefaultShared Yes
# without this iOS offers only A3/A4/A5 in the print dialog
ReadyPaperSizes A4,Letter
WebInterface Yes
DefaultAuthType None
JobSheets none,none
PreserveJobHistory No

<Location />
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>
<Location /admin>
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>
<Location /admin/conf>
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>
<Policy default>
  <Limit All>
    Order deny,allow
  </Limit>
</Policy>
EOL

# --- persist /etc/cups on /share (directory-level symlink) --------
# CUPS rewrites printers.conf atomically (write .N, rename .O, rename .N);
# with per-file symlinks the first rename replaces the symlink with a real
# file in the container layer and the printer is lost on restart.
if [ ! -L /etc/cups ]; then
    for item in /etc/cups/*; do
        [ -e "$item" ] || continue
        base=$(basename "$item")
        case "$base" in cupsd.conf|printers.conf*|ppd|ssl) continue ;; esac
        [ -e "$CFG/$base" ] || cp -r "$item" "$CFG/$base"
    done
    touch "$CFG"/printers.conf
    rm -rf /etc/cups
fi
ln -sfn "$CFG" /etc/cups
touch "$CFG"/printers.conf
mkdir -p /run/cups /run/dbus /var/run/avahi-daemon

# --- sanity: is the HP binary plug-in in place? -------------------
if [ -e /usr/share/hplip/prnt/plugins/lj.so ]; then
    echo "[hplip] binary plug-in present: $(readlink -f /usr/share/hplip/prnt/plugins/lj.so)"
else
    echo "[hplip] WARNING: lj.so missing - host-based LaserJets (M1132/M1136/P1102) will NOT print"
fi
ls /dev/usb/lp* /dev/bus/usb/*/* >/dev/null 2>&1 && echo "[usb] USB device nodes present" || echo "[usb] no USB device nodes visible"

# CUPS security check: cupsd exits silently (before opening any log) if
# these are group/world writable. The old arest add-on left them 0775 on
# /share, which killed cupsd on every start.
chmod 640 "$CFG"/cupsd.conf "$CFG"/cups-files.conf 2>/dev/null || true
chown root:lp "$CFG"/cupsd.conf "$CFG"/cups-files.conf 2>/dev/null || true
echo "[cups] config perms: $(stat -c '%a %n' "$CFG"/cupsd.conf "$CFG"/cups-files.conf 2>/dev/null | tr '\n' ' ')"
