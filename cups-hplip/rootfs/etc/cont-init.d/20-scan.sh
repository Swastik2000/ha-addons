#!/usr/bin/with-contenv bashio
# The M1136 is an MFP. Its scanner needs HPLIP's hpaio SANE backend plus the
# proprietary bb_marvell plug-in (models.dat: scan-type=8, SCAN_TYPE_MARVEL2),
# which 05-hplip-plugin.sh already downloads and installs.
if [ "$(jq -r '.enable_scanning // false' /data/options.json 2>/dev/null)" != "true" ]; then
    bashio::log.info "scanning: disabled - removing the scan UI service entirely"
    rm -rf /etc/services.d/scanui
    exit 0
fi

# hpaio must be listed for SANE to load it
rm -f /tmp/scan.* 2>/dev/null || true

grep -qx 'hpaio' /etc/sane.d/dll.conf 2>/dev/null || echo 'hpaio' >> /etc/sane.d/dll.conf

if [ -e /usr/share/hplip/scan/plugins/bb_marvell.so ]; then
    bashio::log.info "scanning: marvell scan plug-in present"
else
    bashio::log.warning "scanning: bb_marvell.so MISSING - the scanner will not be detected"
fi

bashio::log.info "scanning: probing for the scanner..."
scanimage -L 2>&1 | sed 's/^/[scan] /' || true

bashio::log.info "scanning: UI will be available on http://<ha-ip>:8090"
