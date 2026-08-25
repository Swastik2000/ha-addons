#!/usr/bin/with-contenv bashio
# The M1136 is an MFP. Its scanner needs HPLIP's hpaio SANE backend plus the
# proprietary bb_marvell plug-in (models.dat: scan-type=8, SCAN_TYPE_MARVEL2),
# which 05-hplip-plugin.sh already downloads and installs.
if [ "$(jq -r '.enable_scanning // false' /data/options.json 2>/dev/null)" != "true" ]; then
    bashio::log.info "scanning: disabled - removing the scan UI service entirely"
    rm -rf /etc/services.d/scanui
    exit 0
fi

rm -f /tmp/scan.* /tmp/scan.lock 2>/dev/null || true

# --- serve the UI from /share so it can be edited without rebuilding -------
# Same trick as /etc/cups. The CGI is re-executed per request, so an edit on
# /share is live immediately. The image copy is the seed and the fallback.
WWW=/share/cups/www
if [ ! -f "$WWW/cgi-bin/scan" ]; then
    mkdir -p "$WWW"
    cp -r /var/www/. "$WWW"/ 2>/dev/null || true
    bashio::log.info "scanning: seeded editable UI at $WWW"
fi
chmod -R 755 "$WWW" 2>/dev/null || true
rm -rf /var/www && ln -sfn "$WWW" /var/www
bashio::log.info "scanning: UI served from $WWW (edit there, no rebuild needed)"

grep -qx 'hpaio' /etc/sane.d/dll.conf 2>/dev/null || echo 'hpaio' >> /etc/sane.d/dll.conf

if [ -e /usr/share/hplip/scan/plugins/bb_marvell.so ]; then
    bashio::log.info "scanning: marvell scan plug-in present"
else
    bashio::log.warning "scanning: bb_marvell.so MISSING - the scanner will not be detected"
fi

bashio::log.info "scanning: probing for the scanner..."
timeout 25 scanimage -L 2>&1 | sed 's/^/[scan] /' || true
bashio::log.info "scanning: UI available on http://<ha-ip>:8090"
